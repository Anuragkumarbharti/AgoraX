---
name: Universal Messaging Framework
colors:
  surface: '#f7f9fc'
  surface-dim: '#d8dadd'
  surface-bright: '#f7f9fc'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f2f4f7'
  surface-container: '#eceef1'
  surface-container-high: '#e6e8eb'
  surface-container-highest: '#e0e3e6'
  on-surface: '#191c1e'
  on-surface-variant: '#3c4a3d'
  inverse-surface: '#2d3133'
  inverse-on-surface: '#eff1f4'
  outline: '#6c7b6b'
  outline-variant: '#bbcbb9'
  surface-tint: '#006d2f'
  primary: '#006d2f'
  on-primary: '#ffffff'
  primary-container: '#25d366'
  on-primary-container: '#005523'
  inverse-primary: '#3de273'
  secondary: '#1c695f'
  on-secondary: '#ffffff'
  secondary-container: '#a5ede0'
  on-secondary-container: '#226e63'
  tertiary: '#00668a'
  on-tertiary: '#ffffff'
  tertiary-container: '#48c4ff'
  on-tertiary-container: '#004f6c'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#66ff8e'
  primary-fixed-dim: '#3de273'
  on-primary-fixed: '#002109'
  on-primary-fixed-variant: '#005322'
  secondary-fixed: '#a8f0e3'
  secondary-fixed-dim: '#8cd4c7'
  on-secondary-fixed: '#00201c'
  on-secondary-fixed-variant: '#005047'
  tertiary-fixed: '#c4e7ff'
  tertiary-fixed-dim: '#7cd0ff'
  on-tertiary-fixed: '#001e2c'
  on-tertiary-fixed-variant: '#004c69'
  background: '#f7f9fc'
  on-background: '#191c1e'
  surface-variant: '#e0e3e6'
typography:
  display:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 32px
  headline-sm:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 22px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-md:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.4px
  label-sm:
    fontFamily: Inter
    fontSize: 11px
    fontWeight: '400'
    lineHeight: 14px
  headline-sm-mobile:
    fontFamily: Inter
    fontSize: 17px
    fontWeight: '600'
    lineHeight: 22px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  unit: 4px
  margin-edge: 16px
  gutter-bubble: 8px
  stack-compact: 4px
  stack-default: 12px
  stack-large: 24px
---

## Brand & Style

The design system is built on the principles of **utility, clarity, and approachability**. It aims to foster a sense of immediate connection and reliability, ensuring that the interface never distracts from the conversation. The style is **Corporate Modern**, leveraging familiar patterns to minimize cognitive load while maintaining a crisp, contemporary edge.

Targeted at a global audience, the aesthetic prioritizes high legibility and efficient information density. The emotional response is one of safety and ease; the user should feel that the interface is a transparent window to their personal and professional relationships. 

Key stylistic markers include:
- **High-contrast hierarchy:** Distinguishing clearly between metadata (timestamps, read receipts) and primary content (messages).
- **Subtle Layering:** Using soft surface shifts rather than aggressive shadows to define the workspace.
- **Action-Oriented:** Vital touchpoints are emphasized with a signature brand green to guide the user's intent.

## Colors

The palette is anchored by a vibrant primary green, used for primary actions and status indicators, paired with a deep teal for structural elements like headers and navigation bars. 

- **Primary (#25D366):** Used for the "Send" button, active states, and online indicators.
- **Secondary (#075E54):** Reserved for the top app bar and high-level navigation backgrounds to provide a grounded, authoritative feel.
- **Neutral (#F0F2F5):** The primary background color for chat lists and message threads, providing enough contrast for white message bubbles.
- **Paper (#FFFFFF):** Used for cards, incoming message bubbles, and input fields to signify interactive surfaces.
- **Tertiary (#34B7F1):** A functional blue used for links and secondary system notifications.

## Typography

This design system utilizes **Inter** for its exceptional readability on mobile screens and its neutral, systematic tone. The type scale is designed to handle varying lengths of user-generated content without breaking the layout.

- **Headlines:** Used for contact names and settings headers. Bold weights ensure prominence.
- **Body:** The primary vehicle for chat messages. `body-lg` is optimized for message bubbles to ensure comfort during long reading sessions.
- **Labels:** Small, all-caps or medium weights used for timestamps, read receipts, and secondary metadata.
- **Line Heights:** Generous line-heights are applied to body text to prevent "wall of text" fatigue in dense group chats.

## Layout & Spacing

The layout follows a **fluid-to-safe-area** model, primarily designed for vertical mobile interaction. It relies on a consistent 4px baseline grid.

- **Margins:** A standard 16px horizontal margin is maintained for all list items and text containers.
- **Message Grouping:** Messages from the same sender use a 4px vertical stack (`stack-compact`), while messages between different senders or system prompts use 12px (`stack-default`).
- **Input Bar:** A fixed bottom-sheet layout that remains visible above the keyboard. It uses internal padding of 8px to separate icons from the text entry area.
- **Breakpoints:** On wider screens (tablets), the chat list is pinned to the left (30% width) while the active conversation expands to fill the remaining 70%.

## Elevation & Depth

Hierarchy is established through **Tonal Layering** and very subtle **Ambient Shadows**.

- **Level 0 (Background):** The Light Gray (#F0F2F5) base layer.
- **Level 1 (Incoming Bubbles/Cards):** Pure White (#FFFFFF) with a 1px soft border or a very low-opacity (4%) drop shadow.
- **Level 2 (Outgoing Bubbles):** The Primary Green (#25D366) with a slightly darker green inner-shadow to suggest depth.
- **Level 3 (Sticky Headers/Floating Action Buttons):** These elements use a 12% opacity shadow with an 8px blur to indicate they sit above the scrollable content.
- **Dividers:** Use a subtle 1px line (#E9EDEF) to separate list items in the main dashboard.

## Shapes

The shape language is defined by friendly, organic curves that echo the "approachable" brand pillar.

- **Avatars:** Always strictly circular (50% radius) to differentiate people from content.
- **Chat Bubbles:** `rounded-lg` (1rem) on three corners. The fourth corner (tail) is sharpened to 4px to point toward the sender.
- **Input Fields:** Fully rounded (pill-shaped) to invite interaction.
- **Buttons:** Circular for icon-only actions (like the 'Send' or 'Camera' buttons) and `rounded-lg` for rectangular secondary actions.

## Components

### Chat Bubbles
- **Incoming:** White background, black text. Located on the left.
- **Outgoing:** WhatsApp Green background, black or deep-green text. Located on the right.
- **Metadata:** Timestamps are nested in the bottom right of the bubble with a small gap for status icons (double-check marks).

### Bottom Input Bar
- **Container:** White background, top-border only.
- **Action Icons:** Left side features a '+' or paperclip for attachments. Right side features a 'Gift' icon and a circular 'Mic' or 'Send' button.
- **Text Area:** A pill-shaped gray stroke container that expands vertically up to 5 lines of text.

### Lists (Chat Dashboard)
- **Item Height:** Fixed 72px for standard density.
- **Structure:** Avatar (Left), Name + Timestamp (Top Row), Message Preview + Unread Count (Bottom Row).

### Chips & Badges
- **Unread Count:** Circular, Primary Green background, white bold text, centered vertically on the right of list items.
- **Date Sticky:** A small, centered pill with a semi-transparent gray background and white text used to denote a new day in the thread.

### Selection Controls
- **Checkboxes:** Circular with a primary green fill and white checkmark when active, consistent with the avatar shape language.