"""Usage: python3 make_verity_sheet.py <render dir> <out dir>: stacks before.png (R150) over after.png (R151) into <out dir>/verity_fix.png. Needs Pillow."""
import os
import sys
from PIL import Image

src, out = sys.argv[1], sys.argv[2]
a, b = Image.open(os.path.join(src, 'before.png')).convert('RGB'), Image.open(os.path.join(src, 'after.png')).convert('RGB')
w = max(a.width, b.width)
sheet = Image.new('RGB', (w, a.height + b.height), (20, 22, 28))
sheet.paste(a, (0, 0))
sheet.paste(b, (0, a.height))
sheet.save(os.path.join(out, 'verity_fix.png'))
print('wrote', os.path.join(out, 'verity_fix.png'), sheet.size)
