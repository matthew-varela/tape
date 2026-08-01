# Legal pages — how to publish

The app links to these two URLs from Settings and from the Pro paywall. Both
must return a real page before you invite outside TestFlight testers, and App
Review will check them.

| App link | Must resolve to | Source file |
|---|---|---|
| `AppLinks.privacyPolicy` | `https://watchtape.app/privacy` | `privacy-policy.html` |
| `AppLinks.termsOfService` | `https://watchtape.app/terms` | `terms-of-service.html` |

The `.md` files are the readable source of truth. The `.html` files are the
same text formatted to paste directly into Squarespace.

---

## Publishing on Squarespace

Do this once per page.

1. In the Squarespace dashboard, go to **Pages** and add a new blank page.
2. Name it `Privacy Policy`. Open **Page Settings → General** and set the URL
   slug to exactly `privacy` (so the address is `watchtape.app/privacy`).
3. Edit the page, add a **Code** block, and delete its placeholder contents.
4. Paste the entire contents of `privacy-policy.html`, including the `<style>`
   block at the top. The styles are scoped to `.tape-legal`, so they will not
   affect the rest of your site.
5. Save and publish.
6. Repeat steps 1–5 with `terms-of-service.html`, using the slug `terms`.

Squarespace sometimes places new pages in the "Not Linked" section. That is
fine — the pages are still publicly reachable, which is all Apple requires.
Adding footer links to both is good practice.

### Verify before submitting

Open both URLs in a private browser window (logged out of Squarespace):

- `https://watchtape.app/privacy`
- `https://watchtape.app/terms`

Each should render the full document, not a "Coming Soon" placeholder. If you
still see the parking page, the site is not published yet — publish the site
itself in Squarespace, not just the individual pages.

---

## Where these URLs are also needed

| Location | Field |
|---|---|
| App Store Connect → App Privacy | Privacy Policy URL |
| App Store Connect → App Information | Privacy Policy URL |
| App Store Connect → Subscription | Privacy Policy and Terms of Use (EULA) links |
| In-app Settings screen | Already wired via `AppLinks.swift` |
| In-app Pro paywall | Already wired via `AppLinks.swift` |

---

## Keeping them accurate

These documents describe what the app actually does today. If any of the
following change, update both the `.md` and `.html` versions and re-paste:

- Adding analytics, crash reporting, or advertising SDKs (currently none)
- Collecting new categories of personal data
- Changing the minimum age (currently 13)
- Changing subscription pricing or trial length (currently $9.99/mo, 1-week trial)
- Adding push notifications
- Changing which third parties process data (currently Firebase, Render, Apple)

Update the "Last updated" date whenever you change them.

---

## One caveat

These are thorough drafts written specifically around Tape's actual data
practices, not generic templates. They are not a substitute for review by a
lawyer, which is worth doing before public launch given that the platform
handles content from minors and sells subscriptions.
