/// Handles the iOS share sheet's "Uwearis" entry for shared photos. All the
/// actual work (staging the shared file into the app-group container,
/// relaunching Runner via the ShareMedia-… URL scheme) lives in
/// RSIShareViewController (vendored into this target — see that file's own
/// header comment for why it isn't linked via the receive_sharing_intent
/// package); `shouldAutoRedirect()` defaults to true, so this jumps straight
/// to the app with no intermediate compose UI, matching the Android
/// share-intent flow (a plain SEND intent, no compose step either).
class ShareViewController: RSIShareViewController {
}
