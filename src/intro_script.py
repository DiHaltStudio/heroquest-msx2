"""Script of the intro (the story told by Mentor, from the Amiga opening).

Each entry is a command of the small interpreter in intro.asm:
  ('screen', on)            display on (1) or off (0)
  ('cls', page)             clear a VRAM page
  ('picture', name, page)   load assets/intro/<name>.png into a VRAM page
  ('palette', name)         use the palette of that picture
  ('show', page)            display a VRAM page
  ('wait', frames)          wait (1-255 frames)
  ('text', page, [(y, name), ...])   write texts of assets/intro/texts_es.txt
  ('anim', scene)           run the animation of a scene of animations.json
  ('music',)                start the music
The font and the animation frames are in the picture 'animations', which
stays in page 3. Pictures go to page 0, text screens to pages 1 and 2 (or 0
and 1 between two pictures), so that the next screen is prepared while the
current one is read.
"""
T = ('wait', 227)       # reading time unit of a text screen
A = ('wait', 120)       # pause around the short animations

SCRIPT = [
    ('screen', 0), ('cls', 0), ('cls', 1), ('cls', 2),
    ('picture', 'animations', 3),
    ('picture', 'title', 0), ('palette', 'title'), ('show', 0), ('screen', 1),
    ('music',), T,

    # the village
    ('screen', 0), ('cls', 0),
    ('picture', 'scene0', 0),
    ('picture', 'text_background', 1), ('picture', 'text_background', 2),
    ('text', 1, [(38, 'Scene0_1of2_Pagina1'), (78, 'Scene0_2of2_Pagina1')]),
    ('text', 2, [(74, 'Scene0_Pagina2')]),
    ('palette', 'scene0'), ('show', 0), ('screen', 1),
    ('anim', 0),
    ('screen', 0), ('palette', 'text_background'), ('show', 1), ('screen', 1), T, T, T,
    ('show', 2),

    # the fireplace
    ('cls', 0), ('picture', 'scene1', 0),
    ('picture', 'text_background', 1),
    ('text', 1, [(46, 'Scene1_1of3_Pagina1'), (70, 'Scene1_2of3_Pagina1'), (102, 'Scene1_3of3_Pagina1')]),
    T,
    ('screen', 0), ('palette', 'scene1'), ('show', 0), ('screen', 1),
    ('anim', 1),
    ('screen', 0), ('palette', 'text_background'), ('show', 1), ('screen', 1),

    # Mentor frowns
    ('cls', 0), ('picture', 'scene2', 0),
    ('picture', 'text_background', 2),
    ('text', 2, [(54, 'Scene2_1of2_Pagina1'), (86, 'Scene2_2of2_Pagina1')]),
    T, T,
    ('screen', 0), ('palette', 'scene2'), ('show', 0), ('screen', 1),
    A, ('anim', 2), A,
    ('screen', 0), ('palette', 'text_background'), ('show', 2), ('screen', 1),

    ('cls', 0), ('picture', 'text_background', 0), ('picture', 'text_background', 1),
    ('text', 0, [(38, 'Scene2_1of2_Pagina2'), (78, 'Scene2_2of2_Pagina2')]),
    ('text', 1, [(38, 'Scene2_1of2_Pagina3'), (86, 'Scene2_2of2_Pagina3')]),
    T, T,
    ('show', 0), T, T, T,
    ('show', 1),

    # Morcar studies
    ('cls', 0), ('picture', 'scene3', 0),
    ('picture', 'text_background', 2),
    ('text', 2, [(30, 'Scene3_1of3_Pagina1'), (66, 'Scene3_2of3_Pagina1'), (104, 'Scene3_3of3_Pagina1')]),
    T, T, T,
    ('screen', 0), ('palette', 'scene3'), ('show', 0), ('screen', 1),
    ('anim', 3),
    ('screen', 0), ('palette', 'text_background'), ('show', 2), ('screen', 1),

    ('cls', 0), ('picture', 'text_background', 0), ('picture', 'text_background', 1),
    ('text', 0, [(38, 'Scene3_1of2_Pagina2'), (86, 'Scene3_2of2_Pagina2')]),
    ('text', 1, [(62, 'Scene3_Pagina3')]),
    T, T, T,
    ('show', 0), T, T, T,
    ('show', 1),

    # the skull
    ('picture', 'scene4', 0),
    ('picture', 'text_background', 2),
    ('text', 2, [(30, 'Scene4_1of2_Pagina1'), (86, 'Scene4_2of2_Pagina1')]),
    T, T,
    ('screen', 0), ('palette', 'scene4'), ('show', 0), ('screen', 1),
    ('anim', 4),
    ('screen', 0), ('palette', 'text_background'), ('show', 2), ('screen', 1),

    ('cls', 0), ('picture', 'text_background', 0), ('picture', 'text_background', 1),
    ('text', 0, [(46, 'Scene4_1of2_Pagina2'), (86, 'Scene4_2of2_Pagina2')]),
    ('text', 1, [(30, 'Scene4_1of3_Pagina3'), (62, 'Scene4_2of3_Pagina3'), (94, 'Scene4_3of3_Pagina3')]),
    T, T,
    ('show', 0), T, T, T,
    ('show', 1), T, T, T,

    # the red waste
    ('cls', 0), ('picture', 'scene5', 0),
    ('picture', 'text_background', 2),
    ('text', 2, [(30, 'Scene5_1of3_Pagina1'), (70, 'Scene5_2of3_Pagina1'), (94, 'Scene5_3of3_Pagina1')]),
    T, T, T,
    ('screen', 0), ('palette', 'scene5'), ('show', 0), ('screen', 1),
    A, ('anim', 5), A,
    ('screen', 0), ('palette', 'text_background'), ('show', 2), ('screen', 1),

    ('picture', 'text_background', 1),
    ('text', 1, [(30, 'Scene5_1of3_Pagina2'), (70, 'Scene5_2of3_Pagina2'), (108, 'Scene5_3of3_Pagina2')]),
    T, T, T,
    ('show', 1), T, T,
]
