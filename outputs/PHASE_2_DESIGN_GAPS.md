# Cozy Focus — Phase 2 Design Gaps and Visual Derivation

> Generated: 2026-09-08 | Primary Spec: CozyFocus_Complete_Development_Pack_V2_20260907

---

## 1. Identified Design File Gaps in `designs/`

Upon inspecting `designs/` in the primary product specification:
- `designs/03_专注中.png` is **missing** as an individual design card.
- `designs/03A_暂停状态.png` is **missing** as an individual design card.

Both files exist conceptually in `execution_order.json` and have corresponding comprehensive prompt specifications:
- `prompts/03_专注中_Codex强提示词.md`
- `prompts/03A_暂停状态_Codex强提示词.md`

Furthermore, both screen mockups are visually present in:
- `designs/00C_V2完整页面总览.png` (Screens 03 and 03A in the top row: "01–03 核心专注流程")
- `designs/00B_整体展示_含动效总览.png`

---

## 2. Visual Derivation & Reconciliation Strategy

Rather than inventing arbitrary UI designs, the implementation of Screen 03 (Focusing) and Screen 03A (Paused) is strictly grounded on:

1. **High-Resolution Inspection of `designs/00C_V2完整页面总览.png`**:
   - **03 Focus Session (Running)**:
     - Dark cozy night/warm navy palette (`#1E232A` to `#2A323D` or deep indigo-slate) distinguishing active immersion from daytime setup.
     - Top bar: back/minimize chevron, task category & title subtitle ("Focus Session / Write Product Report").
     - Central element: Large clean digital timer ("25:00" countdown or elapsed countup in Flow mode).
     - Supportive caption: "Mochi is working with you... ♡".
     - Companion visual: Mochi focused at work (typing on laptop / reading / crafting).
     - Controls: Centered pause button (circular, cozy accent).
     - Secondary controls: Ambient sound pill (e.g. "Lo-fi Study"), stop/finish button.
   - **03A Paused State**:
     - Warm ambient background tint overlay.
     - Top title: "Paused".
     - Central element: Frozen elapsed time.
     - Companion visual: Mochi resting/sleeping peacefully on a cozy mat.
     - Actions: Prominent pill button "Continue" (primary sage green), secondary rounded button "End Early" (soft warm peach/beige).
   - **03C Early Finish Confirmation**:
     - Modal card over dimmed focus background with Mochi caring illustration, "End Focus Early?", "You've focused for X minutes. Are you sure you want to end?", "Keep Going" (primary) and "End Anyway" (secondary).
   - **03B Background / Lock Screen**:
     - Standard system notification preview with live status and clean return CTA.

2. **Color Palette & Theme Consistency**:
   - Primary Sage Green: `#5E8D6D` / `#4E785C`
   - Warm Cream / Background: `#FBF8F2` / `#F5EFE6`
   - Card Surface: `#FFFFFF` with soft 12–16px corner radius and subtle warm shadow
   - Accent Peach / Coral: `#E28768` / `#F4A261`
   - Text Primary: `#2D312E`, Text Secondary: `#7D827E`
   - Typography: Clean rounded sans-serif hierarchy matching Mochi's gentle aesthetic.
