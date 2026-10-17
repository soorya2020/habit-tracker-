import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/firebase_auth_service.dart';
import '../data/firestore_repository.dart';
import '../domain/models.dart';
import 'providers.dart';

enum Stage { signedOut, loading, setup, claim, notInvited, ready, error }

/// Where the signed-in Google account stands with the club.
class Account {
  const Account(this.stage, {this.email = '', this.memberId, this.invite, this.error});

  final Stage stage;
  final String email;
  final String? memberId;

  /// The member waiting for this email, for [Stage.claim].
  final Profile? invite;
  final String? error;
}

/// True when Firebase started; otherwise the app runs on this phone only.
final cloudModeProvider = Provider<bool>((ref) => false);

final accountProvider = NotifierProvider<AccountNotifier, Account>(AccountNotifier.new);

class AccountNotifier extends Notifier<Account> {
  StreamSubscription? _sub;

  FirestoreRepository get _repo => ref.read(repositoryProvider) as FirestoreRepository;
  GoogleAuth get _auth => GoogleAuth.instance;

  @override
  Account build() {
    if (!ref.watch(cloudModeProvider)) return const Account(Stage.signedOut);
    _sub = _auth.changes().listen((_) => _resolve());
    ref.onDispose(() => _sub?.cancel());
    return const Account(Stage.loading);
  }

  Future<void> _resolve() async {
    final u = _auth.user;
    if (u == null) {
      state = const Account(Stage.signedOut);
      return;
    }
    final email = (u.email ?? '').toLowerCase();
    state = Account(Stage.loading, email: email);
    try {
      final member = await _repo.memberFor(u.uid);
      if (member != null) {
        await _repo.backfillHistory(member).catchError((_) {});
        state = Account(Stage.ready, email: email, memberId: member);
      } else if (!await _repo.clubExists()) {
        state = Account(Stage.setup, email: email);
      } else {
        final invite = await _repo.invitedAs(email);
        state = invite != null
            ? Account(Stage.claim, email: email, invite: invite)
            : Account(Stage.notInvited, email: email);
      }
    } catch (e) {
      state = Account(Stage.error, email: email, error: '$e');
    }
  }

  Future<void> signIn() async {
    try {
      state = const Account(Stage.loading);
      await _auth.signIn();
      // authStateChanges resolves the rest.
    } catch (e) {
      state = Account(Stage.signedOut, error: 'Sign-in did not finish. $e');
    }
  }

  Future<void> createClub(String memberId) async {
    final u = _auth.user!;
    state = Account(Stage.loading, email: state.email);
    try {
      await _repo.createClub(memberId: memberId, authUid: u.uid, email: u.email ?? '');
      await _resolve();
    } catch (e) {
      state = Account(Stage.error, email: state.email, error: '$e');
    }
  }

  Future<void> claim() async {
    final invite = state.invite!;
    state = Account(Stage.loading, email: state.email);
    try {
      await _repo.claim(invite, _auth.user!.uid);
      await _resolve();
    } catch (e) {
      state = Account(Stage.error, email: state.email, error: '$e');
    }
  }

  Future<void> retry() => _resolve();

  Future<void> signOut() => _auth.signOut();
}
