# Evos Admin Panel Guide

*Last updated: 31 Oct 2026*

The admin panel lets you give each install link its own app name, logo, colours, prices, paywall words, login slides and web page. You don't need an app update. Each of these setups is called a **source**: the short tag in the link people install from, such as `filmyface`.

---

## 1. Before you start

You need two things from the developer:

| What | Why |
|---|---|
| **The panel's web address** | The panel is a small website. The developer hosts it or runs it for you. |
| **The admin password** | It unlocks the panel. Keep it private: anyone with it can change what users see and pay. |

If the panel refuses every password, the password hasn't been set yet. Ask the developer to set it.

---

## 2. Open the panel

1. Open the panel's web address in Chrome or Safari on a computer.
2. Type the admin password and click **Unlock**.
3. You see **Campaign sources**: one row for each source you have already made.

The password stays in that browser tab only. Click **Lock** at the top when you are done, especially on a shared computer.

---

## 3. Add a new source

1. Click **+ New source**.
2. Fill in **Source tag**: one lowercase word with no spaces, for example `filmyface` or `diwali-offer`. This must match the `utm_source` in the install link (see [section 6](#6-make-the-install-link-for-a-source)). **You cannot change it after saving.**
3. Leave **Status** on **Active — used by the app**.
4. Fill in only what should be different for this source (see [section 4](#4-what-each-field-changes)). Leave everything else blank.
5. Watch the phone on the right while you type: it shows exactly what this source's users will see.
6. Click **Save**.

To change a source later, click it in the list, edit, and click **Save**. **Cancel** leaves without saving. **Delete** removes the source for good (it asks first; this cannot be undone).

---

## 4. What each field changes

The **Basics** are always shown. Everything else is under **Show advanced options**.

Each field shows a tag: **Default** means it's blank and uses the normal app setting, shown in grey inside the box. **Custom** means this source has its own value.

### Basics

| Field | What it changes | Example |
|---|---|---|
| App name | The name on the sign-in, paywall and web page screens | `FilmyFace` |
| Logo image | The logo. A link to a square image starting with `https://`. Blank shows the first letter of the name | `https://…/logo.png` |
| Brand colour | Every screen's colours are built from this one colour | `#E11D48` |
| Website link | The page a user opens after paying. Must start with `https://` | `https://example.com` |
| Trial price (today) | What the user pays today for the first 24 hours | `3` |
| Monthly price | What is charged every month after the trial (read the [price rule](#5-rules-to-remember) first) | `299` |
| Short tagline | One line under the paywall heading. Optional | `Unlimited movies, one price` |
| Button text | The main paywall button | `Try Now` |

### Advanced options

| Group | Field | What it changes |
|---|---|---|
| Branding | Highlight colour | The price pill, the big price and the icons. Blank uses the brand colour |
| Paywall heading | Heading — first part / pill / last part | The big heading, for example "1-Day" + "₹3" pill + "Trial". A blank pill shows the trial price |
| Trust and social proof | Rating, Rating caption | A star rating line. Blank hides it |
| | Social proof lines | Short lines that change every 3 seconds under the price. Put `\|` between lines |
| | Social proof icon | The icon beside those lines |
| Features | 4 rows of icon + label | The list of benefits on the paywall. Click the round icon to choose one |
| Preview media | Preview image, Preview video, Video shape | The picture or video on the paywall. Video shape is `9:16` (tall) or `16:9` (wide) |
| Options | Strike through the monthly price | Shows the monthly price crossed out next to the trial price |
| Payment wording | Auto-pay sentence | The sentence saying money is taken every month. Write `{trial}` and `{recurring}` where the prices go |
| | UPI chooser label, UPI sheet title | Words on the UPI app picker |
| Plan | Plan name, Cashfree plan id | Payment settings, not shown to users. Only change them with the developer |
| Login slideshow | Image + caption rows | The moving pictures on the sign-in screen |

---

## 5. Rules to remember

- **Blank means "use the normal app setting".** You only fill what should differ.
- **Login slideshow is the exception.** If a source has no slides of its own, its users see **no slideshow**. They never see the normal app's slides.
- **Monthly price: read this before changing it.** The app has a Cashfree plan set for everyone. While that plan is set, the monthly price you type here changes only the price **shown**; the amount actually **charged** each month is still the plan's. To really charge a different monthly amount, ask the developer to make a Cashfree plan for it and put its id in **Cashfree plan id**. The **trial price** is always charged as you set it.
- **Hide instead of delete.** Set **Status** to **Hidden — ignored by the app** to switch a source off without losing it.
- **When users see changes.** The app picks up changes the next time it loads its settings, usually the next time it opens. A change to the login slideshow shows from the launch after that.
- **Meta (Facebook/Instagram) ad installs arrive as `apps.facebook.com`**, not `facebook`. A source called `facebook` does not apply to them. To style Meta ad users, make sources called `apps.facebook.com` and `apps.instagram.com`.

---

## 6. Make the install link for a source

Give people a Play Store link with your source tag in it. Replace `filmyface` with your tag:

```
https://play.google.com/store/apps/details?id=com.spacewire.evos&referrer=utm_source%3Dfilmyface
```

To also track the campaign and the ad, add them the same way (`%3D` means `=`, `%26` means `&`):

```
https://play.google.com/store/apps/details?id=com.spacewire.evos&referrer=utm_source%3Dfilmyface%26utm_campaign%3Ddiwali%26utm_content%3Dvideo1
```

The source is saved the first time the app opens after install, and it never changes for that phone.

---

## 7. Check your work

1. **The phone preview** (right side of the editor) updates as you type.
   - Click any field: the preview jumps to the screen it changes and outlines that part in orange.
   - **All screens** shows all six screens at once: Sign-in, Code, Paywall, UPI apps, Processing and Web page.
   - **Dark** shows the dark theme.
   - On a small screen, use the **Preview** button to open it.
2. **On a real phone:** install from your link on a phone with **no work or Google Workspace account** on it (such accounts make Play hide the source). Open the app and check the sign-in screen and the paywall.

Preview limits:

- The paywall video plays without sound; click **Sound** to hear it.
- Some websites refuse to show inside the preview. They still open in the app. Use **Open the site ↗** under the phone.

---

## 8. What the panel cannot change, and common problems

**Not in this panel** (ask the developer):

- The **normal app settings** that every source starts from. They live in Supabase, table `app_config`.
- Payment keys, SMS settings, and who has paid.
- The website's own content. The panel only sets which website opens.

**Common problems**

| Problem | What to do |
|---|---|
| "Unlock" fails | Check the password. If it still fails, the password isn't set yet: ask the developer |
| My change doesn't show in the app | Close the app fully and open it again. Check the source's **Status** is **Active** |
| Users from my link see the normal app | The link's `utm_source` must match the **Source tag** exactly, lowercase. Test on a phone with no work account |
| The slideshow disappeared for my source | The source has no slides of its own. Add slides under **Login slideshow** |
| The monthly charge didn't change | See the monthly price rule in [section 5](#5-rules-to-remember) |
| The web page shows "refused to connect" in the preview | That site blocks previews. Check it with **Open the site ↗** or in the app |
