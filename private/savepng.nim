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
import streams

import filter
import png
import zutil

proc writeNInt32(s: Stream, val: uint32) {. inline .} =
    s.write(uint8(val shr 24))
    s.write(uint8(val shr 16))
    s.write(uint8(val shr 8))
    s.write(uint8(val))

type
    PngEncoderOpts* = object
        colorType: ColorType

proc default_opts*(): PngEncoderOpts =
    PngEncoderOpts(colorType: rgba)

proc new_opts*(colorType: ColorType): PngEncoderOpts =
    ## Create an encoder options struct for a given color type. Note that for
    ## grayscale color types, the value in the red channel is taken as the
    ## gray value; green and blue channels are ignored, and the alpha channel is
    ## ignored for gray (but not graya).
    PngEncoderOpts(colorType: colorType)

proc to_png(img: Image, opts: PngEncoderOpts): PngImage =
    new(result)
    result.width = img.width
    result.height = img.height
    result.data = img.data
    result.depth = 8
    result.colorType = opts.colorType
    result.interlaced = 0

proc write_header(buf: Stream) =
    for v in PNG_HEADER:
        buf.write(uint8(v))

proc write_chunk(buf: Stream, chunktype: string, chunk: string) =
    buf.writeNInt32(uint32(chunk.len))
    buf.write(chunktype)
    buf.write(chunk)
    buf.writeNInt32(zcrc(chunktype, chunk))

proc write_IHDR(buf: Stream, img: PngImage) =
    var chunk = newStringStream()
    chunk.writeNInt32(uint32(img.width))
    chunk.writeNInt32(uint32(img.height))
    chunk.write(img.depth)
    chunk.write(uint8(img.colorType))
    chunk.write(0'u8) # zlib compression
    chunk.write(0'u8) # default filter
    chunk.write(0'u8) # not interlaced
    buf.write_chunk("IHDR", chunk.data)

proc to_rgba(c: NColor): string =
    itostr(uint32(c))

proc to_rgb(c: NColor): string =
    itostr(uint32(c), 3)

proc to_gray(c: NColor): string =
    itostr(uint32(c), 1)

proc to_graya(c: NColor): string =
    itostr(uint32(c), 1) & itostr(uint32(c) shl 24, 1)

proc write_IDAT(buf: Stream, img: PngImage) =
    var chunk = newStringStream()
    let sl_len = img.width * img.bpp
    var last_scanline: string
    for r in 0..<img.height:
        var scanline = newString(sl_len)
        for c in 0..<img.width:
            var cstr: string
            let color = img[r, c]
            case img.colorType
            of rgba:
                cstr = color.to_rgba()
            of rgb:
                cstr = color.to_rgb()
            of gray:
                cstr = color.to_gray()
            of graya:
                cstr = color.to_graya()
            else:
                raise newException(
                    ValueError, "only rgb, rgba, gray and graya images are supported")
            assert(cstr.len == img.bpp)
            copyMem(addr(scanline[c * img.bpp]), addr(cstr[0]), img.bpp)
        let filter = filter.choose_filter(img, scanline, last_scanline)
        var filtered = newString(scanline.len)
        filter.apply(img.bpp, scanline, last_scanline, filtered)
        last_scanline = scanline
        chunk.write(uint8(filter))
        chunk.writeData(addr(filtered[0]), len(filtered))
    var compressed = zcompress(chunk.data)
    buf.write_chunk("IDAT", compressed)

proc write_IEND(buf: Stream) =
    buf.write_chunk("IEND", "")

proc save_png*(img: Image, buf: Stream, opts: PngEncoderOpts) =
    let img = to_png(img, opts)
    buf.write_header()
    buf.write_IHDR(img)
    buf.write_IDAT(img)
    buf.write_IEND()

proc save_png*(img: Image, buf: Stream) =
    save_png(img, buf, default_opts())
