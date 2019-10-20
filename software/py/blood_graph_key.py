import sys
from blood_graph import BloodGraph
from PIL import Image, ImageDraw, ImageFont
from itertools import chain

WIDTH  = 256
HEIGHT = 256

if __name__ == "__main__":

    if len(sys.argv) == 1:
        mode = "detailed"
    elif len(sys.argv) == 2:
        mode = sys.argv[1] 

    bg = BloodGraph(0,1,1, mode)
    img = Image.new("RGB", (WIDTH, HEIGHT), "black")
    draw = ImageDraw.Draw(img)
    font = ImageFont.load_default()
    # get the size of the font
    yt = 0
    # for each color in stalls...
    for (key,color) in chain(bg.stall_bubble_color.iteritems(),
                             [("unified_instr"    ,bg.unified_instr_color),
                              ("unified_fp_instr" ,bg.unified_fp_instr_color),
                              ("unknown"          ,bg.unknown_color)]):
        (font_height,font_width) = font.getsize(key)
        yb = yt + font_width
        #color = bg.stall_bubble_color[key]
        draw.rectangle([0, yt, 64, yb], color)
        draw.text((68, yt), key, (255,255,255))
        yt += font_width

    #draw.text((0,0), "Sample Text", (255,255,255), font=font)
    img.save("key.bmp")

