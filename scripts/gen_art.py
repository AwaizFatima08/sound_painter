#!/usr/bin/env python3
"""Generate every Gemini image the app and store listing use.

Skips files that already exist, so rerunning only fills gaps. Delete a file in
art/raw/ to regenerate it. Characters and objects are drawn on white and cut
out by scripts/process_art.py; backgrounds are used as they come.

  python3 scripts/gen_art.py [name ...]
"""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent))
import gemini  # noqa: E402

RAW = gemini.ROOT / "art" / "raw"

CHAR = ("Children's picture-book character illustration for toddlers: soft rounded shapes, thick smooth "
        "outlines in dark plum, gentle cel shading, friendly big eyes, warm pastel colours with a few glowing "
        "neon accents. Full body, centred, facing the viewer, lots of empty margin around it. Plain flat pure "
        "white background, no shadow on the ground, no scenery, absolutely no text, letters or numbers.")
SAME = "Keep this exact same character design, colours, proportions and drawing style as the reference image."
OBJ = ("Children's picture-book illustration for toddlers of a single object: soft rounded shapes, thick "
       "smooth outlines in dark plum, gentle cel shading, bright cheerful saturated colours, a cute friendly "
       "face is NOT allowed, just the object. Centred with lots of empty margin. Plain flat pure white "
       "background, no shadow, no scenery, absolutely no text, letters or numbers.")
BADGE = ("Round glossy app-style badge illustration for a toddler game, soft rounded shapes, thick smooth plum "
         "outlines, glowing pastel-neon colours on a deep purple circle. Centred, with empty margin around the "
         "circle. Plain flat pure white background outside the circle, absolutely no text, letters or numbers.")
AVATAR = ("Round avatar badge for a toddler game: a cute animal face, head and shoulders only, soft rounded "
          "shapes, thick smooth plum outlines, gentle cel shading, big friendly eyes, inside a filled pastel "
          "circle. Centred with empty margin. Plain flat pure white background outside the circle, absolutely "
          "no text, letters or numbers.")
SCENE = ("Soft dreamy children's picture-book background painting for a toddler game, wide landscape. Deep "
         "blues and soft purples, gentle glow, very calm, low detail, soft focus, no characters, no animals, no "
         "people, absolutely no text, letters or numbers. Full-bleed: the painting fills the whole canvas edge to "
         "edge, with no border, frame, vignette edge or white margin.")

PIP = "Pip, a small chubby baby penguin with a round belly, wearing a long knitted scarf that glows softly in teal."
OLLIE = "Ollie, a round fluffy baby owl in soft caramel and cream feathers, with huge gentle eyes and wing tips that glow warm amber."
ARIA = ("Aria, a wise, friendly little sea turtle with a gentle smile, soft green skin, and a rounded shell covered "
        "in geometric hexagon segments that glow softly in aqua and violet.")

# name: (prompt, reference name or None, aspect)
ART = {
    "pip_idle": (f"{CHAR} Character: {PIP} Pose: standing happily, wings slightly out, smiling.", None, "1:1"),
    "pip_low": (f"{CHAR} {SAME} Character: {PIP} Pose: crouched down low and cozy, snuggled into the scarf up to the beak, eyes gently closed, content.", "pip_idle", "1:1"),
    "pip_high": (f"{CHAR} {SAME} Character: {PIP} Pose: leaping up joyfully in the air, both wings stretched wide open, beak open in delight, scarf flying.", "pip_idle", "1:1"),
    "pip_wave": (f"{CHAR} {SAME} Character: {PIP} Pose: waving goodbye with one wing, warm sleepy smile.", "pip_idle", "1:1"),
    "ollie_idle": (f"{CHAR} Character: {OLLIE} Pose: perched upright, wings folded, friendly smile.", None, "1:1"),
    "ollie_quiet": (f"{CHAR} {SAME} Character: {OLLIE} Pose: wings wrapped snugly around its body, eyes wide open, listening very carefully.", "ollie_idle", "1:1"),
    "ollie_loud": (f"{CHAR} {SAME} Character: {OLLIE} Pose: wings flung wide open and flapping, little glowing feathers flying off, joyful expression.", "ollie_idle", "1:1"),
    "aria_idle": (f"{CHAR} Character: {ARIA} Pose: seen from the side three-quarter view, head tilted forward toward the viewer, listening kindly.", None, "1:1"),
    "aria_happy": (f"{CHAR} {SAME} Character: {ARIA} Pose: joyful, head up, flippers raised, every shell segment glowing brightly.", "aria_idle", "1:1"),
    "obj_apple": (f"{OBJ} Object: a shiny red apple with a green leaf.", None, "1:1"),
    "obj_egg": (f"{OBJ} Object: a big speckled egg sitting in a little straw nest.", None, "1:1"),
    "obj_igloo": (f"{OBJ} Object: a small round snowy igloo made of blue-white ice blocks, with a dark arched door.", None, "1:1"),
    "obj_octopus": (f"{OBJ} Object: a cheerful purple octopus with curly tentacles (a simple dot-eye face is fine for the octopus).", None, "1:1"),
    "obj_umbrella": (f"{OBJ} Object: an open umbrella with bright rainbow-coloured panels and a curved handle.", None, "1:1"),
    "badge_canvas": (f"{BADGE} Inside the circle: a painter's palette with blobs of glowing rainbow paint and a paintbrush, with musical sparkles.", None, "1:1"),
    "badge_safari": (f"{BADGE} Inside the circle: a tiny jungle island with palm trees, big leaves and a winding path.", None, "1:1"),
    "badge_gallery": (f"{BADGE} Inside the circle: a golden picture frame holding a colourful swirly child's painting.", None, "1:1"),
    "avatar_fox": (f"{AVATAR} Animal: a little orange fox. Circle colour: soft peach.", None, "1:1"),
    "avatar_bunny": (f"{AVATAR} Animal: a little white bunny with pink ears. Circle colour: soft pink.", None, "1:1"),
    "avatar_bear": (f"{AVATAR} Animal: a little brown bear cub. Circle colour: soft yellow.", None, "1:1"),
    "avatar_frog": (f"{AVATAR} Animal: a little green frog. Circle colour: soft mint.", None, "1:1"),
    "avatar_elephant": (f"{AVATAR} Animal: a little grey-blue baby elephant. Circle colour: soft lilac.", None, "1:1"),
    "avatar_cat": (f"{AVATAR} Animal: a little ginger kitten. Circle colour: soft sky blue.", None, "1:1"),
    "bg_home": (f"{SCENE} A night sky full of soft twinkling stars above gentle rolling purple hills, a big friendly glowing moon, the middle of the image left open and calm.", None, "16:9"),
    "bg_canvas": (f"{SCENE} An almost plain, very dark indigo-to-deep-purple gradient night sky with a few faint tiny stars near the edges, nearly empty, like a blank canvas.", None, "16:9"),
    "bg_safari": (f"{SCENE} A friendly jungle clearing at twilight, big soft leaves and palm fronds framing the edges, fireflies, the centre open and uncluttered.", None, "16:9"),
    "bg_warmup": (f"{SCENE} A calm icy night landscape with soft snowdrifts, a small ice block platform in the lower centre, aurora ribbons glowing gently in the sky.", None, "16:9"),
    "store_icon": ("App icon artwork for a toddler voice-painting game: Pip, a small chubby baby penguin with a round belly "
                   "and a glowing teal knitted scarf, singing happily with beak open while glowing rainbow paint ribbons "
                   "swirl out around it, on a deep purple-to-indigo background. Full-bleed square artwork: the background "
                   "fills the entire canvas to all four edges and corners, with NO rounded corners, no icon shape, no "
                   "border, no white margin and no drop shadow (the store applies its own mask). Keep Pip within the "
                   "central 80%. Bold, simple, readable at small size, soft rounded shapes, thick plum outlines. "
                   "Absolutely no text, letters or numbers.", "pip_idle", "1:1"),
    "store_feature": ("Wide banner artwork for a toddler voice-painting game: on the right side, Pip the baby penguin "
                      "with a glowing teal scarf singing, Ollie the baby owl and Aria the little sea turtle beside it, "
                      "glowing rainbow paint ribbons flowing out from Pip's song across the picture. The left 45% of "
                      "the image is a calm, mostly empty deep indigo night sky with a few stars (space for a title "
                      "added later). Soft picture-book style, thick plum outlines. Absolutely no text, letters or "
                      "numbers.", "pip_idle", "21:9"),
}


def main(names):
    RAW.mkdir(parents=True, exist_ok=True)
    for name in names or ART:
        prompt, ref, aspect = ART[name]
        out = RAW / f"{name}.png"
        if out.exists():
            continue
        refs = [RAW / f"{ref}.png"] if ref else []
        if name == "store_feature":
            refs += [RAW / "ollie_idle.png", RAW / "aria_idle.png"]
        print("generating", name, flush=True)
        gemini.image(prompt, out, refs, aspect)


if __name__ == "__main__":
    main(sys.argv[1:])
