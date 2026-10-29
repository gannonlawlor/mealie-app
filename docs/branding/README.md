# Cookbook icon

Approved design: cream folded recipe page with a steaming bowl on terracotta.
The app name is not embedded in the icon.

`icon-master.png` was generated with the built-in imagegen tool from the approved
concept. `scripts/export-icons.py` separates its two colors, normalizes the fills,
and exports the platform assets. Run it from any directory using Python with Pillow.
The exported palette is terracotta `#B54122` and cream `#FFF7E6`.

iOS includes opaque 1024px default, dark, and grayscale tinted assets. Android
includes legacy icons and adaptive background, transparent foreground, and
monochrome layers at all five launcher densities. The adaptive artwork has extra
padding for launcher masks and motion.

Generation prompt:

> Create a production square app-icon asset from the approved large icon in the reference. Output ONLY the icon, filling the entire square canvas edge to edge with a uniform solid terracotta background (#B54122). No rounded outer corners: platform applies the mask. Center the same cream (#FFF7E6) recipe page with rounded lower corners and folded upper-right corner. Inside retain the same terracotta shallow bowl with small base and two thick curved steam strokes. Match approved geometry closely. The entire page including fold should occupy about 56% of canvas width and 68% of height, centered. Bowl entirely within page with clear padding. Crisp flat two-color artwork, exact uniform solid fills, no gradients, textures, lighting, shadows, text, title, presentation background, small repeat or extra objects. This is an actual full bleed square iOS and Android icon master, not a presentation mockup.
