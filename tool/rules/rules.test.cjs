const {test, before, after} = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const {initializeTestEnvironment, assertSucceeds, assertFails} = require('@firebase/rules-unit-testing');
const {doc, getDoc, setDoc, updateDoc, writeBatch, serverTimestamp, Timestamp} = require('firebase/firestore');
let env;
const tank = 'facilities/f/sections/s/tanks/t';
before(async () => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) throw Error('Local emulator required; production is forbidden');
  env = await initializeTestEnvironment({projectId: 'demo-fjellfisk-qa', firestore: {
    host: '127.0.0.1', port: 8787,
    rules: fs.readFileSync(path.resolve(__dirname, '../../firestore.rules'), 'utf8')
  }});
  await env.withSecurityRulesDisabled(async ctx => {
    const db = ctx.firestore();
    for (const role of ['admin', 'ansatt', 'leser']) {
      await setDoc(doc(db, 'users/' + role), {role, disabled: false, email: role+'@example.invalid'});
    }
    await setDoc(doc(db, 'users/disabled'), {role: 'admin', disabled: true});
    await setDoc(doc(db, 'users/legacy'), {role: 'ansatt'});
    await setDoc(doc(db, tank), {fishCount: 100});
    await setDoc(doc(db, 'feed_inventory/f'), {stockKg: 100});
  });
});
after(async () => { if (env) await env.cleanup(); });
function db(uid) {return env.authenticatedContext(uid, {email: uid+'@example.invalid'}).firestore();}
test('anonymous, unknown and disabled users cannot read production', async () => {
  for (const store of [env.unauthenticatedContext().firestore(), db('unknown'), db('disabled')]) {
    await assertFails(getDoc(doc(store, tank)));
    await assertFails(setDoc(doc(store, tank+'/logs/new'), {feedKg: 1}));
  }
});
test('reader can read but cannot modify tank, log, stock, sample, note or roles', async () => {
  const store = db('leser');
  await assertSucceeds(getDoc(doc(store, tank)));
  for (const p of [tank, tank+'/logs/reader', tank+'/weightSamples/reader',
    tank+'/tankNotes/reader', 'feed_inventory/f', 'users/leser']) {
    await assertFails(setDoc(doc(store, p), {role: 'admin', disabled: false, fishCount: 0}));
  }
});
test('employee can atomically register log, stock and sample but not roles/structure', async () => {
  const store = db('ansatt');
  const batch = writeBatch(store);
  batch.update(doc(store, tank), {fishCount: 99});
  batch.set(doc(store, tank+'/logs/employee'), {date: Timestamp.now(), avgWeight: 250});
  batch.set(doc(store, tank+'/weightSamples/employee'), {averageGram: 250});
  batch.update(doc(store, 'feed_inventory/f'), {stockKg: 98});
  batch.set(doc(store, 'feed_inventory_history/employee'), {changeKg: -2});
  await assertSucceeds(batch.commit());
  await assertFails(updateDoc(doc(store, 'users/ansatt'), {role: 'admin'}));
  await assertFails(updateDoc(doc(store, tank), {name: 'changed'}));
});
test('legacy active profile without disabled field is consistent with app', async () => {
  await assertSucceeds(getDoc(doc(db('legacy'), tank)));
});
test('admin can change roles and disable; reader cannot create invitations', async () => {
  await assertSucceeds(updateDoc(doc(db('admin'), 'users/legacy'), {role: 'leser', disabled: false}));
  await assertFails(setDoc(doc(db('leser'), 'userInvites/no'), {role: 'admin'}));
});
test('invitation permits matching account only and cannot elevate its role', async () => {
  const token = 'local-test-invite';
  const email = 'new@example.invalid';
  await assertSucceeds(setDoc(doc(db('admin'), 'userInvites/'+token), {
    email, emailLower: email, displayName: 'Test', role: 'ansatt', status: 'pending',
    createdAt: serverTimestamp(), createdByUid: 'admin', createdByEmail: 'admin@example.invalid',
    updatedAt: serverTimestamp(), acceptedAt: null, acceptedByUid: null,
    disabled: false, inviteToken: token, expiresAt: Timestamp.fromMillis(Date.now()+86400000)
  }));
  const profile = {email, emailLower: email, name: 'Test', role: 'ansatt', disabled: false,
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(), inviteId: token};
  await assertFails(setDoc(doc(db('wrong'), 'users/wrong'), profile));
  await assertFails(setDoc(doc(db('new'), 'users/new'), {...profile, role: 'admin'}));
  const store = env.authenticatedContext('new', {email: 'New@Example.invalid'}).firestore();
  const batch = writeBatch(store);
  batch.set(doc(store, 'users/new'), profile);
  batch.update(doc(store, 'userInvites/'+token), {status: 'accepted', acceptedAt: serverTimestamp(),
    acceptedByUid: 'new', updatedAt: serverTimestamp()});
  await assertSucceeds(batch.commit());
});
test('diary creation and updates obey author, role and immutable fields', async () => {
  const data = {title:'Test',body:'Local emulator only',category:'Annet',
    createdAt:serverTimestamp(),updatedAt:serverTimestamp(),entryDate:Timestamp.now(),
    createdByUid:'ansatt',createdByEmail:'ansatt@example.invalid',createdByName:'Test',
    updatedByUid:'ansatt',updatedByEmail:'ansatt@example.invalid',status:'active'};
  const p = 'facilities/f/diaryEntries/entry';
  await assertFails(setDoc(doc(db('leser'), p), data));
  await assertSucceeds(setDoc(doc(db('ansatt'), p), data));
  await assertSucceeds(updateDoc(doc(db('ansatt'), p), {title:'Updated',updatedAt:serverTimestamp()}));
  await assertFails(updateDoc(doc(db('ansatt'), p), {status:'archived',updatedAt:serverTimestamp()}));
  await assertSucceeds(updateDoc(doc(db('admin'), p), {status:'archived',updatedAt:serverTimestamp(),
    updatedByUid:'admin',updatedByEmail:'admin@example.invalid'}));
});
test('employee can create, edit and resolve notes; reader can only read', async () => {
  const p = tank+'/tankNotes/note';
  await assertSucceeds(setDoc(doc(db('ansatt'), p), {text:'Local note',status:'active'}));
  await assertSucceeds(updateDoc(doc(db('ansatt'), p), {text:'Updated',status:'resolved'}));
  await assertSucceeds(getDoc(doc(db('leser'), p)));
  await assertFails(updateDoc(doc(db('leser'), p), {text:'Not allowed'}));
});
