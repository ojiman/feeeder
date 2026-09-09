# Offline feed import and original-page navigation

Approved scope: specification F-01/F-03/F-04, reader-first amendment, user request to continue. Coordinator executes inline; autonomous workers stay gated.

1. Add synthetic tests for RSS2/content namespace, RDF/DC, Atom alternate links/xml:base, malformed XML and entity rejection. Implement a bounded XMLParser delegate returning value types; no URL fetching.
2. Test import/reimport, cross-feed URL deduplication, rename/folder persistence and unsubscribe retaining likes/body. Extend SwiftData with optional/defaulted fields and FeedMembership; migrate existing demo memberships without resetting data. Import parses before mutations and saves transactionally.
3. Add XML-paste sheet with source URL and built-in synthetic examples. Add subscription editing and removal. Keep network refresh out of this slice. Parsing runs off the main actor.
4. Add b external and v WebKit original-page routes for valid HTTP(S) URLs, Esc return preserving the mounted reader and list. Do not intercept text/IME input. Test URL and navigation decisions offline; never visit remote pages during agent verification.
5. Run Swift tests and app build, inspect local GUI if available, document partial acceptance and remaining runtime checks, commit locally. No push, dependencies, credentials or Keychain.

Record actual test-first failures and passing checks in the turn and validation note. F-02 performance, full F-03 focus/scroll coverage, F-05 extraction, F-06 persisted browser sessions and all outstanding harness gates remain unaccepted.
