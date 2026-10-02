import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/user_invite.dart';
import '../services/user_invite_service.dart';
import '../services/user_service.dart';
import '../l10n/localizations.dart';

class AdminUsersScreen extends StatelessWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: UserService.getCurrentUserRole(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data != 'admin') {
          return Scaffold(
            appBar: AppBar(title: Text(context.l10n.usersAndAccess)),
            body: const _AccessDenied(),
          );
        }
        return const _AdminUsersView();
      },
    );
  }
}

class _AdminUsersView extends StatelessWidget {
  const _AdminUsersView();

  Future<void> _openInviteSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: const SingleChildScrollView(child: _InviteFormPanel()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Fjellfisk 3.0',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth >= 1050;
          final pagePadding = desktop ? 24.0 : 16.0;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(pagePadding, 22, pagePadding, 40),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PageHeader(
                      showButton: !desktop,
                      onInvite: () => _openInviteSheet(context),
                    ),
                    const SizedBox(height: 20),
                    if (desktop)
                      const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _UsersAndInvites()),
                          SizedBox(width: 16),
                          SizedBox(width: 370, child: _InviteFormPanel()),
                        ],
                      )
                    else
                      const _UsersAndInvites(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.showButton, required this.onInvite});

  final bool showButton;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.usersAndAccess,
                style: const TextStyle(
                  color: Color(0xFF0A1733),
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                context.l10n.manageUsersSubtitle,
                style: const TextStyle(color: Color(0xFF5F7088), fontSize: 14),
              ),
            ],
          ),
        ),
        if (showButton) ...[
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: onInvite,
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: Text(context.l10n.inviteUser),
          ),
        ],
      ],
    );
  }
}

class _UsersAndInvites extends StatelessWidget {
  const _UsersAndInvites();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _UsersPanel(),
        SizedBox(height: 16),
        _InvitesPanel(),
      ],
    );
  }
}

class _UsersPanel extends StatefulWidget {
  const _UsersPanel();

  @override
  State<_UsersPanel> createState() => _UsersPanelState();
}

class _UsersPanelState extends State<_UsersPanel> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _update(
    Future<void> Function() action,
    String success,
  ) async {
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success)),
      );
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Brukeroppdatering feilet: $error\n$stackTrace');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.couldNotUpdateUser)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: UserService.usersStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            if (kDebugMode) {
              debugPrint('Brukerlesing feilet: ${snapshot.error}');
            }
            return _PanelError(context.l10n.usersUnavailable);
          }
          if (!snapshot.hasData) {
            return const SizedBox(
              height: 180,
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final query = _searchController.text.trim().toLowerCase();
          final users = snapshot.data!.docs.where((document) {
            final data = document.data();
            final email = (data['email'] ?? '').toString().toLowerCase();
            final name = (data['name'] ?? '').toString().toLowerCase();
            return query.isEmpty ||
                email.contains(query) ||
                name.contains(query);
          }).toList();

          return Column(
            children: [
              _PanelHeader(
                icon: Icons.group_outlined,
                title: context.l10n.usersAndAccess,
                count: snapshot.data!.docs.length,
                trailing: SizedBox(
                  width: 230,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: context.l10n.searchUsers,
                      prefixIcon: const Icon(Icons.search),
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              if (users.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(30),
                  child: Text(context.l10n.noUsersFound),
                )
              else
                for (final document in users)
                  _UserRow(
                    document: document,
                    onRole: (role) => _update(
                      () => UserService.updateUserRole(
                        userId: document.id,
                        role: role,
                      ),
                      context.l10n.roleUpdated,
                    ),
                    onDisabled: (disabled) => _update(
                      () => UserService.setUserDisabled(
                        userId: document.id,
                        disabled: disabled,
                      ),
                      disabled
                          ? context.l10n.userDisabled
                          : context.l10n.userEnabled,
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({
    required this.document,
    required this.onRole,
    required this.onDisabled,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> document;
  final ValueChanged<String> onRole;
  final ValueChanged<bool> onDisabled;

  @override
  Widget build(BuildContext context) {
    final data = document.data();
    final email = (data['email'] ?? context.l10n.unknownEmail).toString();
    final name = (data['name'] ?? '').toString().trim();
    final role = _safeRole(data['role']);
    final disabled = data['disabled'] == true;
    final isCurrentUser = document.id == UserService.currentUserId;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 680;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFFE7EDF4))),
          ),
          child: compact
              ? Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _UserIdentity(
                            name: name,
                            email: email,
                            disabled: disabled,
                          ),
                        ),
                        _StatusBadge(
                          label: disabled
                              ? context.l10n.statusDisabled
                              : context.l10n.statusActive,
                          color: disabled
                              ? const Color(0xFF7F8997)
                              : const Color(0xFF0BA765),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _RoleDropdown(
                            value: role,
                            onChanged: onRole,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          tooltip: disabled
                              ? context.l10n.activateUser
                              : context.l10n.deactivateUser,
                          onPressed: isCurrentUser
                              ? null
                              : () => onDisabled(!disabled),
                          icon: Icon(
                            disabled
                                ? Icons.person_add_alt
                                : Icons.person_off_outlined,
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: _UserIdentity(
                        name: name,
                        email: email,
                        disabled: disabled,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: _RoleDropdown(value: role, onChanged: onRole),
                    ),
                    Expanded(
                      flex: 2,
                      child: _StatusBadge(
                        label: disabled
                            ? context.l10n.statusDisabled
                            : context.l10n.statusActive,
                        color: disabled
                            ? const Color(0xFF7F8997)
                            : const Color(0xFF0BA765),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        _formatDate(
                          context,
                          data['lastActive'] ?? data['updatedAt'],
                        ),
                        style: const TextStyle(
                          color: Color(0xFF5F7088),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: context.l10n.actions,
                      enabled: !isCurrentUser,
                      onSelected: (_) => onDisabled(!disabled),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: disabled ? 'activate' : 'disable',
                          child: Text(
                            disabled
                                ? context.l10n.activateUser
                                : context.l10n.deactivateUser,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _UserIdentity extends StatelessWidget {
  const _UserIdentity({
    required this.name,
    required this.email,
    required this.disabled,
  });

  final String name;
  final String email;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor:
              disabled ? const Color(0xFFE4E7EB) : const Color(0xFFE7F1FF),
          child: Icon(
            disabled ? Icons.person_off_outlined : Icons.person_outline,
            size: 19,
            color: disabled ? const Color(0xFF7F8997) : const Color(0xFF0B63E5),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.isEmpty ? email : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF0A1733),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (name.isNotEmpty)
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF708096),
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoleDropdown extends StatelessWidget {
  const _RoleDropdown({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        isDense: true,
        borderRadius: BorderRadius.circular(7),
        items: [
          DropdownMenuItem(value: 'admin', child: Text(context.l10n.roleAdmin)),
          DropdownMenuItem(
              value: 'ansatt', child: Text(context.l10n.roleEmployee)),
          DropdownMenuItem(
              value: 'leser', child: Text(context.l10n.roleReader)),
        ],
        onChanged: (value) {
          if (value != null && value != this.value) onChanged(value);
        },
      ),
    );
  }
}

class _InvitesPanel extends StatelessWidget {
  const _InvitesPanel();

  Future<void> _copy(BuildContext context, UserInvite invite) async {
    await Clipboard.setData(
      ClipboardData(text: UserInviteService.inviteLink(invite.id)),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.invitationLinkCopied)),
    );
  }

  Future<void> _revoke(BuildContext context, UserInvite invite) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.revokeInvitationQuestion),
        content: Text(invite.email),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.revokeInvitation),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await UserInviteService.revokeInvite(invite.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.invitationRevoked)),
      );
    } catch (error, stackTrace) {
      if (kDebugMode) debugPrint('Tilbakekalling feilet: $error\n$stackTrace');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.couldNotRevokeInvitation)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: StreamBuilder<List<UserInvite>>(
        stream: UserInviteService.invitesStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            if (kDebugMode) debugPrint('Invitasjonslesing: ${snapshot.error}');
            return _PanelError(context.l10n.invitationsUnavailable);
          }
          if (!snapshot.hasData) {
            return const SizedBox(
              height: 130,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final invites = snapshot.data!;
          return Column(
            children: [
              _PanelHeader(
                icon: Icons.mark_email_unread_outlined,
                title: context.l10n.invitations,
                count: invites.length,
              ),
              const Divider(height: 1),
              if (invites.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(28),
                  child: Text(context.l10n.noInvitations),
                )
              else
                for (final invite in invites)
                  _InviteRow(
                    invite: invite,
                    onCopy: () => _copy(context, invite),
                    onRevoke: invite.canBeUsed
                        ? () => _revoke(context, invite)
                        : null,
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _InviteRow extends StatelessWidget {
  const _InviteRow({
    required this.invite,
    required this.onCopy,
    required this.onRevoke,
  });

  final UserInvite invite;
  final VoidCallback onCopy;
  final VoidCallback? onRevoke;

  @override
  Widget build(BuildContext context) {
    final color = _inviteStatusColor(invite.effectiveStatus);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE7EDF4))),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.1),
            child: Icon(Icons.mail_outline, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invite.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF0A1733),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${_roleLabel(context, invite.role)} · ${context.l10n.expiresOn(DateFormat('dd.MM.yyyy').format(invite.expiresAt))}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF5F7088),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          _StatusBadge(
            label: _inviteStatusLabel(context, invite.effectiveStatus),
            color: color,
          ),
          PopupMenuButton<String>(
            tooltip: context.l10n.invitationActions,
            onSelected: (value) {
              if (value == 'copy') onCopy();
              if (value == 'revoke') onRevoke?.call();
            },
            itemBuilder: (context) => [
              if (invite.canBeUsed)
                PopupMenuItem(
                  value: 'copy',
                  child: Text(context.l10n.copyInvitationLink),
                ),
              if (onRevoke != null)
                PopupMenuItem(
                  value: 'revoke',
                  child: Text(context.l10n.revokeInvitation),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InviteFormPanel extends StatefulWidget {
  const _InviteFormPanel();

  @override
  State<_InviteFormPanel> createState() => _InviteFormPanelState();
}

class _InviteFormPanelState extends State<_InviteFormPanel> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  String _role = 'ansatt';
  bool _loading = false;
  String? _error;
  UserInvite? _created;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final invite = await UserInviteService.createInvite(
        email: _emailController.text,
        role: _role,
        displayName: _nameController.text,
      );
      if (!mounted) return;
      setState(() => _created = invite);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.invitationCreated)),
      );
    } on UserInviteException catch (error) {
      if (mounted) setState(() => _error = _inviteErrorMessage(context, error));
    } catch (error, stackTrace) {
      if (kDebugMode) debugPrint('Invitasjon feilet: $error\n$stackTrace');
      if (mounted) {
        setState(() => _error = context.l10n.couldNotCreateInvitation);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.invitationLinkCopied)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.person_add_alt_1_outlined,
                  color: Color(0xFF0B63E5),
                ),
                const SizedBox(width: 9),
                Text(
                  context.l10n.invitePanelTitle,
                  style: const TextStyle(
                    color: Color(0xFF0A1733),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: context.l10n.nameOptional,
                hintText: context.l10n.fullNameHint,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: context.l10n.email,
                hintText: context.l10n.emailHint,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: InputDecoration(labelText: context.l10n.role),
              items: [
                DropdownMenuItem(
                    value: 'admin', child: Text(context.l10n.roleAdmin)),
                DropdownMenuItem(
                    value: 'ansatt', child: Text(context.l10n.roleEmployee)),
                DropdownMenuItem(
                    value: 'leser', child: Text(context.l10n.roleReader)),
              ],
              onChanged: _loading
                  ? null
                  : (value) {
                      if (value != null) setState(() => _role = value);
                    },
            ),
            const SizedBox(height: 10),
            Text(
              context.l10n.invitationRoleInfo,
              style: const TextStyle(color: Color(0xFF708096), fontSize: 11),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(
                  color: Color(0xFFD53C3C),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loading ? null : _create,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                label: Text(context.l10n.createInvitation),
              ),
            ),
            if (_created != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF3FF),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: const Color(0xFFC9DEFA)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Color(0xFF0B63E5)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(context.l10n.invitationReady)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _copy(
                    UserInviteService.inviteLink(_created!.id),
                  ),
                  icon: const Icon(Icons.link),
                  label: Text(context.l10n.copyInvitationLink),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () => _copy(_invitationText(context, _created!)),
                  icon: const Icon(Icons.content_copy),
                  label: Text(context.l10n.copyInvitationText),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.icon,
    required this.title,
    required this.count,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final int count;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF0B63E5)),
          const SizedBox(width: 9),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF0A1733),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 8),
          _CountBadge(count),
          if (trailing != null) ...[
            const Spacer(),
            Flexible(child: trailing!),
          ],
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDCE5EF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08082C51),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3FF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Color(0xFF0B63E5),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _PanelError extends StatelessWidget {
  const _PanelError(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF7F8997)),
          const SizedBox(width: 9),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _AccessDenied extends StatelessWidget {
  const _AccessDenied();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          context.l10n.accessDeniedUserAdmin,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

String _safeRole(Object? value) {
  final role = (value ?? 'leser').toString();
  return UserService.roles.contains(role) ? role : 'leser';
}

String _roleLabel(BuildContext context, String role) {
  if (role == 'admin') return context.l10n.roleAdmin;
  if (role == 'ansatt') return context.l10n.roleEmployee;
  return context.l10n.roleReader;
}

String _formatDate(BuildContext context, Object? value) {
  if (value is! Timestamp) return context.l10n.notRegistered;
  return DateFormat('dd.MM.yyyy').format(value.toDate());
}

String _inviteStatusLabel(BuildContext context, String status) {
  return switch (status) {
    'accepted' => context.l10n.invitationStatusAccepted,
    'revoked' => context.l10n.invitationStatusRevoked,
    'expired' => context.l10n.invitationStatusExpired,
    _ => context.l10n.invitationStatusPending,
  };
}

String _inviteErrorMessage(BuildContext context, UserInviteException error) {
  return switch (error.code) {
    'invalid-email' => context.l10n.invalidEmail,
    'invalid-role' => context.l10n.invalidRole,
    'user-exists' => context.l10n.emailAlreadyRegistered,
    'invite-exists' => context.l10n.activeInvitationExists,
    'permission-denied' => context.l10n.accessDeniedUserAdmin,
    'unavailable' => context.l10n.inviteServiceUnavailable,
    _ => context.l10n.couldNotCreateInvitation,
  };
}

String _invitationText(BuildContext context, UserInvite invite) {
  final name = invite.displayName.trim();
  final greeting = name.isEmpty
      ? context.l10n.invitationGreeting
      : context.l10n.invitationGreetingNamed(name);
  return '$greeting\n\n${context.l10n.invitationCopyBody(
    invite.email,
    UserInviteService.inviteLink(invite.id),
  )}';
}

Color _inviteStatusColor(String status) {
  if (status == 'accepted') return const Color(0xFF0BA765);
  if (status == 'revoked') return const Color(0xFFD53C3C);
  if (status == 'expired') return const Color(0xFF7F8997);
  return const Color(0xFF0B63E5);
}
