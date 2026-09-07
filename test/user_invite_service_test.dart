import 'package:fjellfisk/models/user_invite.dart';
import 'package:fjellfisk/services/user_invite_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserInviteService', () {
    test('normaliserer og validerer e-post', () {
      expect(
        UserInviteService.normalizeEmail(' Ansatt@Eksempel.NO '),
        'ansatt@eksempel.no',
      );
      expect(UserInviteService.isValidEmail('ansatt@eksempel.no'), isTrue);
      expect(UserInviteService.isValidEmail('ugyldig-adresse'), isFalse);
    });

    test('lager stabil invitasjonslenke og norsk invitasjonstekst', () {
      final invite = UserInvite(
        id: 'sikkert-token',
        email: 'ansatt@eksempel.no',
        displayName: 'Ola Nordmann',
        role: 'ansatt',
        status: 'pending',
        createdAt: DateTime(2026, 9, 7),
        expiresAt: DateTime(2026, 9, 14),
      );

      expect(
        UserInviteService.inviteLink(invite.id),
        'https://trolltungaarctictrout.web.app/#/invite/sikkert-token',
      );
      expect(
        UserInviteService.invitationText(invite),
        contains('ansatt@eksempel.no'),
      );
      expect(
        UserInviteService.invitationText(invite),
        contains('Hei Ola Nordmann!'),
      );
    });
  });

  test('utløpt pending-invitasjon får status Utløpt', () {
    final invite = UserInvite(
      id: 'utlopt',
      email: 'ansatt@eksempel.no',
      role: 'leser',
      status: 'pending',
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
      expiresAt: DateTime.now().subtract(const Duration(days: 3)),
    );

    expect(invite.canBeUsed, isFalse);
    expect(invite.effectiveStatus, 'expired');
    expect(invite.statusLabel, 'Utløpt');
  });
}
