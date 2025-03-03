# Copyright (c) 2015, Haldean Brown
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# * Neither the name of nimage nor the names of its
#   contributors may be used to endorse or promote products derived from
#   this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import image

type
    ColorType* = enum
        gray = 0
        rgb = 2
        palette = 3
        graya = 4
        rgba = 6
    PngImage* = ref object of Image
        depth*: uint8
        colorType*: ColorType
        interlaced*: uint8
        palette*: array[0..255, NColor]

proc `$`*(x: PngImage): string =
    "(img w " & $x.width & " h " & $x.height & " depth " & $x.depth & " colorType " & $x.colorType & ")"

const PNG_HEADER* = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]

proc bpp*(img: PngImage): int =
    ## Returns the bytes per pixel for the given image
    let d = int(int(img.depth) / 8)
    assert(d * 8 == int(img.depth)) # We only support multiple-of-8 image depths
    case img.colorType
    of gray:    d
    of rgb:     3 * d
    of palette: d
    of graya:   2 * d
    of rgba:    4 * d

proc intToStr*(val: uint32, n = 4): string {.inline.} =
    ## Converts an integer to a string, as if the bytes had been copied directly
    ## out of the integer and into the bytestring. Copies the most-significant N
    ## bytes.
    for i in 0..<n:
        result.add(char((val shr uint32(8 * (3 - i))) and 0xFF))

template strToInt*(s: string): uint32 =
    ## Gets the integer representation of a 4-character string. This does the
    ## safe-ish equivalent of "*((int*)(c_str))" in C. This does not check the
    ## bounds on its inputs!
    #uint32(
    (uint32(s[0]) shl 24 or
     uint32(s[1]) shl 16 or
     uint32(s[2]) shl  8 or
     uint32(s[3]))
