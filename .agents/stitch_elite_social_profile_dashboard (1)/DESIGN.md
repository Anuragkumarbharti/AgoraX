---
name: Aura Premium Social
colors:
  surface: '#11131c'
  surface-dim: '#11131c'
  surface-bright: '#373943'
  surface-container-lowest: '#0c0e17'
  surface-container-low: '#191b24'
  surface-container: '#1d1f29'
  surface-container-high: '#282933'
  surface-container-highest: '#32343e'
  on-surface: '#e1e1ef'
  on-surface-variant: '#c6c5d7'
  inverse-surface: '#e1e1ef'
  inverse-on-surface: '#2e303a'
  outline: '#8f8fa0'
  outline-variant: '#454655'
  surface-tint: '#bec2ff'
  primary: '#bec2ff'
  on-primary: '#000da4'
  primary-container: '#5865f2'
  on-primary-container: '#fffdff'
  inverse-primary: '#3f4cda'
  secondary: '#fff9ef'
  on-secondary: '#3a3000'
  secondary-container: '#ffdb3c'
  on-secondary-container: '#725f00'
  tertiary: '#ddb7ff'
  on-tertiary: '#490080'
  tertiary-container: '#9c48eb'
  on-tertiary-container: '#fffcff'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#e0e0ff'
  primary-fixed-dim: '#bec2ff'
  on-primary-fixed: '#000569'
  on-primary-fixed-variant: '#222fc2'
  secondary-fixed: '#ffe16d'
  secondary-fixed-dim: '#e9c400'
  on-secondary-fixed: '#221b00'
  on-secondary-fixed-variant: '#544600'
  tertiary-fixed: '#f0dbff'
  tertiary-fixed-dim: '#ddb7ff'
  on-tertiary-fixed: '#2c0051'
  on-tertiary-fixed-variant: '#6900b3'
  background: '#11131c'
  on-background: '#e1e1ef'
  surface-variant: '#32343e'
typography:
  display-lg:
    fontFamily: Inter
    fontSize: 48px
    fontWeight: '700'
    lineHeight: 56px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  username:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '700'
    lineHeight: 20px
  stats-value:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
  body-main:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  bio-text:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
    letterSpacing: 0.01em
  label-caps:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.05em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base-unit: 4px
  container-padding: 20px
  gutter: 16px
  card-gap: 12px
  section-margin: 32px
---

## Brand & Style

This design system is engineered for a high-end social experience that blends the community-centric density of Discord with the visual storytelling of Instagram. The aesthetic is rooted in **Dark Glassmorphism**, creating a sense of infinite depth and premium exclusivity. 

The target audience consists of digital natives, creators, and VIP communities who value a sophisticated, "night-mode-first" environment. The UI should feel atmospheric, immersive, and sleek. Every layer uses translucency and backdrop blurs to maintain a connection to the content beneath, while gold and indigo accents signify status and platform authority.

## Colors

The palette is anchored by a **Deep Space Navy** (#0F111A) background. Interactivity and primary actions are driven by **Deep Indigo**, while **Premium Gold** is reserved strictly for VIP status, high-level verification, and special achievements.

- **Primary (Indigo):** Used for standard buttons, active navigation states, and links.
- **Secondary (Gold):** Used for "Star" features, VIP tiers, and premium badges.
- **Surface Strategy:** Backgrounds are never solid. Surfaces use a layered approach with varying levels of transparency and `backdrop-filter: blur(12px)`.
- **Gradients:** VIP elements utilize a linear gradient from Rich Purple (#A855F7) to Premium Gold (#FFD700) at 135 degrees.

## Typography

The design system utilizes **Inter** across all levels to ensure maximum readability against dark, blurred backgrounds. 

- **Hierarchy:** High contrast in font weight is used to distinguish identity from content. Usernames are always bold to establish presence.
- **Readability:** Bio text uses a slightly tighter line-height and letter-spacing for a clean, editorial look in profile headers.
- **Stats:** Numbers (followers, likes, levels) are given a semi-bold weight and slightly larger scale than body text to highlight social proof.
- **Mobile scaling:** For `display-lg`, reduce size to 32px on mobile devices while maintaining the tight letter spacing.

## Layout & Spacing

This system uses a **fluid 12-column grid** for desktop and a **single-column stack** for mobile. 

- **Rhythm:** All spacing is derived from a 4px baseline. Most components use 16px or 20px internal padding.
- **Safe Areas:** On mobile, side margins are fixed at 20px to ensure glass cards don't touch the screen edge.
- **Depth Hierarchy:** More important content "floats" higher with larger margins and more pronounced blurs. Secondary sidebar elements on desktop use narrower gutters (12px) to feel more utility-focused.

## Elevation & Depth

Depth is communicated through **Z-axis stacking and refraction** rather than traditional black shadows.

1.  **Base:** Deep Navy (#0F111A), 0% blur.
2.  **Level 1 (Feed Cards):** `background: rgba(255, 255, 255, 0.04)`, `backdrop-filter: blur(12px)`, 1px border `rgba(255, 255, 255, 0.08)`.
3.  **Level 2 (Modals/Popovers):** `background: rgba(255, 255, 255, 0.08)`, `backdrop-filter: blur(24px)`, 1px border `rgba(255, 255, 255, 0.15)`.
4.  **Floating Elements:** Buttons and FABs use a subtle outer glow of their own primary color (e.g., Indigo glow) instead of a shadow to enhance the "neon" premium feel.

## Shapes

The design system uses a **Rounded** (8px to 24px) aesthetic to balance the technical nature of glassmorphism with a soft, social feel.

- **Standard Cards:** 16px border-radius (`rounded-lg`).
- **Interactive Elements:** Buttons and input fields use 12px border-radius.
- **Avatars:** Circular (full-round) for users; Squircle for server/community icons.
- **Chips:** Fully pill-shaped for status and verification tags.

## Components

### Buttons
- **Primary:** Solid Indigo background with white text. High-contrast and vibrant.
- **Secondary:** Glass background with 1px Indigo border.
- **VIP:** Linear gradient (Purple to Gold) with black text for maximum punch.

### Chips & Verification
- **Verified:** Electric Cyan (#00F5FF) text and icon on a low-opacity cyan glass base.
- **Roles:** Use a 10% opacity version of the role color for the background and 100% opacity for the text.

### Cards
- Every card must have a 1px top-down inner highlight (linear-gradient(to bottom, rgba(255,255,255,0.1), rgba(255,255,255,0.02))) to simulate light hitting the top edge of the glass.

### Input Fields
- Dark, translucent backgrounds (rgba(0,0,0,0.2)) with a 1px border that glows Indigo on focus.

### Lists
- Items are separated by a 1px glass line (`rgba(255, 255, 255, 0.05)`). Hover states for list items should trigger a subtle brightness increase rather than a color change.