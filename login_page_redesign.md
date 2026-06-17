# Login Page Redesign — Website (React)

## Overview
Redesign the `/login` route into a two-panel split layout (form on the left, brand visual on the right) — the same layout *pattern* as the reference mockup the user provided, but built entirely from LendWUs's existing dark/green brand system instead of the mockup's pink/light-blue palette and stock 3D illustration. No new design language is introduced; everything below is pulled from tokens and components that already exist in this repo, so the result reads as part of the same product as the landing page, not a bolted-on template.

## Scope
- **Edit:** `website/src/pages/Login.tsx` and the `.app-login-*` rules in `website/src/App.css` (currently around line 2431, "APP LOGIN" section)
- **Do not touch:** `AuthContext.tsx`, `firebase.ts`, routing in `App.tsx`, the Flutter mobile app, or `pages/admin/Login.tsx` / `pages/member/Login.tsx` (see Cleanup note at the bottom — both are dead code, unrouted)

## Design tokens to reuse (already defined in `App.css :root` — do not redefine)
| Token | Value | Use here |
|---|---|---|
| `--background` | `#0d1117` | page background |
| `--surface` / `--surface-elevated` | `#161b22` / `#1c2128` | input fields, panel edges |
| `--primary` → `--primary-dark` | `#1a4d2e` → `#0f331e` | right-panel gradient (same as the existing logo-icon gradient) |
| `--highlight` | `#2ecc71` | primary button, focus states, links |
| `--highlight-dim` | `rgba(46,204,113,.15)` | badge chips |
| `--text` / `--text-secondary` / `--text-muted` | `#e6edf3` / `#c9d1d9` / `#8b949e` | headings / body / labels |
| `--border-strong` | `#30363d` | input borders |
| `--error` | `#e74c3c` | form error state |
| font | `'Plus Jakarta Sans'` | already global via `index.css` |

Note: the current `.app-login-submit` button is hardcoded to `#22c55e`, which is close to but *not* `--highlight` (`#2ecc71`). Standardize on `var(--highlight)` while doing this rebuild.

## Layout

### Desktop ≥900px (matches the breakpoint already used for the hero's grid collapse)
- Single rounded card, `max-width: 1040px`, centered in the viewport, `background: var(--surface-elevated)`, subtle `border: 1px solid var(--border)`, `border-radius: 24px`, `overflow: hidden`, soft shadow.
- Two-column grid inside: left panel `1.1fr` / right panel `0.9fr`.
- Left panel: `background: var(--background)`, padding ~56px, contains the form.
- Right panel: full-bleed gradient brand visual (see below), no padding on the gradient itself.

### Mobile <900px
- Right panel is removed entirely (`display: none`), not stacked below — same pattern the hero already uses for `.phone-mockup` on small screens, so there's no precedent-breaking new behavior.
- Card becomes full-width with no rounded corners, left panel padding drops to 24px (matches the existing 480px breakpoint padding convention elsewhere in `App.css`).

## Left panel — form

1. **Brand mark:** reuse the exact navbar markup, just smaller — `<a className="logo">Lend<span>WUs</span></a>` — top-left, not centered. Drop the circular emoji icon block currently in `Login.tsx`; it's the only piece of this page not echoed anywhere else on the site.
2. **Eyebrow + heading**, directly mirroring the reference mockup's hierarchy:
   - small muted line: `Welcome back`
   - large heading: `Sign in to LendWUs` (`font-size: var(--text-4xl)`, `font-weight: 800`)
3. **Form fields**, label-above-input (the reference mockup's pattern, and a real accessibility improvement over today's placeholder-only inputs):
   - `<label>Email</label>` then the existing email input (keep the `AtSign` icon inside it)
   - `<label>Password</label>` with **Forgot password?** aligned to the right of that same label row (move it up from its current position below the field, to match the mockup), then the password input (keep `Lock` / show-hide eye icon)
4. **Primary button:** full-width pill (`border-radius: 999px`), `background: var(--highlight)`, keep existing copy ("Sign In" / "Signing in…"), add a trailing `ArrowRight` icon (already imported elsewhere in `App.tsx`, just import it into `Login.tsx`) to match the mockup's arrow-in-button detail.
5. **Divider:** keep existing "OR CONTINUE WITH" treatment.
6. **Social login:** keep the single working Google button only. The mockup shows Google/GitHub/Facebook icons, but only Google is wired up in `AuthContext` — do not add GitHub/Facebook buttons with no handler behind them; that's dead UI.
7. **Footer:** restyle the existing two links ("Enter group code" / "Back to Home") as a single centered line, e.g. `New here? Enter group code · Back to Home`, echoing the mockup's "Don't have an account? Sign up for free" pattern without inventing a signup flow that doesn't exist (joining happens via the group code, not a generic signup form).

## Right panel — brand visual (replaces the mockup's stock illustration)

Nothing here should be a new illustration asset. Reuse what the hero already renders:

- **Background:** the same gradient already used for the login logo icon, scaled to fill the panel — `linear-gradient(135deg, #1a4d2e 0%, #0d2818 100%)`.
- **Decorative glow:** reuse the hero's `::before`/`::after` soft radial green glow (`radial-gradient(circle, rgba(46,204,113,.06) 0%, transparent 70%)`), repositioned for this panel.
- **Centerpiece:** the existing `.phone-mockup` component, showing just the Dashboard screen (disable the screen-cycling interval for this static context), with two of the existing `.phone-float-badge` elements floating beside it (💰 Total Fund, 📈 Interest) — same components, same classes, just re-mounted here.
- **Trust row below the phone:** reuse the exact `.hero-trust` three items verbatim (Secure & Private / Real-time Sync / No Hidden Fees, with `CheckCircle` icons), recolored for the dark green background — swap `--text-muted` for a translucent white (`rgba(255,255,255,.85)`) so it stays legible against the gradient.
- Wrap the whole panel in `aria-hidden="true"` — it's decorative and shouldn't be in the tab order, same treatment the hero gives its phone mockup.

## New CSS to add (extend, don't replace, the existing `.app-login-*` block)
- `.app-login-shell` — outer centered card, grid container
- `.app-login-panel-left` — existing form wrapper (current `.app-login-card` styles move here)
- `.app-login-panel-right` — gradient visual panel
- `.app-login-eyebrow` / `.app-login-heading` — new text hierarchy described above
- `.app-login-field-row` — label + "Forgot password?" on the same line
- `.app-login-trust` — recolored copy of `.hero-trust` for dark green background
- Update `.app-login-submit` to `border-radius: 999px` and `background: var(--highlight)`

## Implementation steps
1. In `App.css`, duplicate the "APP LOGIN" section into the structure above; keep old class names working where reused so `Login.tsx` doesn't need a full rewrite of its state/handlers — only its JSX layout changes.
2. In `Login.tsx`: wrap existing form markup in the new panel structure, add `<label>` elements, move "Forgot password?" up next to the Password label, add the `ArrowRight` import and icon to the submit button, add the new right-panel JSX block (logo gradient + phone mockup + trust row), mark it `aria-hidden`.
3. Add a `900px` media query hiding `.app-login-panel-right` and collapsing the grid to one column, matching the convention already used for the hero.
4. Verify `:focus-visible` outline (`outline: 2px solid #22c55e` defined globally) still shows correctly on the new pill-shaped inputs/button — don't override it.
5. Spot-check color contrast for the white trust-row text against the green gradient (use `rgba(255,255,255,.85)` or higher, not the page's `--text-muted` gray, which is too dark on that background).

## QA checklist
- Email/password login still authenticates and redirects to the correct dashboard (admin vs member) — handlers are untouched, only JSX moved.
- Google sign-in still works.
- Forgot-password success/error states still render correctly in the new layout.
- "Enter group code" and "Back to Home" links still route to `/member/unrecognized` and `/`.
- Visual check at 1440px, 1024px, 900px (breakpoint edge), 768px, and 390px.
- No new npm dependencies were added — this is achievable with the existing `lucide-react` icons and plain CSS (no `framer-motion` in `package.json`, so keep animations CSS-only, same as the rest of the site).

## Out of scope
- `AuthContext.tsx` / `firebase.ts` logic — unchanged.
- The Flutter mobile app's login screen — separate task if you want that redesigned too, since it's a different codebase/design system entirely.
- `pages/admin/Login.tsx` and `pages/member/Login.tsx` — both currently unrouted dead code (`/admin` and `/member/login` both redirect to `/login` in `App.tsx`). Worth deleting in a follow-up cleanup, but not part of this change.
