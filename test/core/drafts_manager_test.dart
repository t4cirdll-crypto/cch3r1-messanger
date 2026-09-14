import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cch3r1_messanger/core/utils/drafts_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(
        {'draft_shared-chat': 'unowned legacy draft'});
    await DraftsManager.init();
  });

  test('drafts in a shared conversation remain isolated by account', () async {
    await DraftsManager.saveDraft('shared-chat', 'Account A draft',
        accountId: 'A');
    expect(DraftsManager.getDraft('shared-chat', accountId: 'B'), isNull);
    await DraftsManager.saveDraft('shared-chat', 'Account B draft',
        accountId: 'B');
    await DraftsManager.clearDraft('shared-chat', accountId: 'A');
    expect(DraftsManager.getDraft('shared-chat', accountId: 'A'), isNull);
    expect(DraftsManager.getDraft('shared-chat', accountId: 'B'),
        'Account B draft');
    expect(DraftsManager.getDraft('shared-chat', accountId: null), isNull);
  });

  test('legacy drafts without an owner are never restored into an account', () {
    expect(DraftsManager.getDraft('shared-chat', accountId: 'new-account'),
        isNull);
  });
}
