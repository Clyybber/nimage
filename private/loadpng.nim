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

import streams
import strutils

import filter
import image
import png
import zutil

const DEBUG = false

proc readNInt32(s: Stream): int32 {. inline .} =
    (int32(s.readUint8) shl 24) or
     (int32(s.readUint8) shl 16) or
     (int32(s.readUint8) shl 8) or
     (int32(s.readUint8))

proc load_ihdr(img: PngImage, chunkData: string) =
    var buf = newStringStream(chunkData)
    img.width = buf.readNInt32
    img.height = buf.readNInt32
    img.depth = buf.readUint8
    img.colorType = ColorType(buf.readUint8)
    let
        compression = buf.readUint8
        filter = buf.readUint8
    img.interlaced = buf.readUint8
    if compression != 0:
        raise newException(ValueError, "unknown compression type " & $compression)
    if filter != 0:
        raise newException(ValueError, "unknown filter type " & $filter)
    if img.interlaced != 0:
        raise newException(ValueError, "unsupported interlace type " & $img.interlaced)
    if img.depth != 8:
        raise newException(ValueError, "unsupported color depth " & $img.depth)
    img.data = newSeq[NColor](img.height * (img.width * img.bpp + 1))

proc read_gray(stream: var StringStream): NColor =
    let g = uint32(stream.readUint8)
    NColor((uint32(g) shl 24) or (uint32(g) shl 16) or (g shl 8) or 0xFF'u32)

proc read_graya(stream: var StringStream): NColor =
    let
        g = uint32(stream.readUint8)
        a = uint32(stream.readUint8)
    NColor((uint32(g) shl 24) or (uint32(g) shl 16) or (g shl 8) or a)

proc read_rgb(stream: var StringStream): NColor =
    let
        r = uint32(stream.readUint8)
        g = uint32(stream.readUint8)
        b = uint32(stream.readUint8)
    NColor((uint32(r) shl 24) or (uint32(g) shl 16) or (uint32(b) shl 8) or 0xFF'u32)

proc read_rgba(stream: var StringStream): NColor =
    NColor(stream.readNInt32)

proc read_palette(stream: var StringStream, img: PngImage): NColor =
    img.palette[stream.readUint8]

proc load_idat(img: var PngImage, chunkData: string) =
    let uncompressed = zuncompress(chunkData)
    when DEBUG: echo("  decompressed to " & $len(uncompressed) & " bytes")
    let scanlines = int(len(uncompressed) / (img.width * img.bpp + 1))
    assert(scanlines * (img.width * img.bpp + 1) == len(uncompressed))
    assert(scanlines == img.height)
    var r = 0
    var buf = newStringStream(uncompressed)
    var last_scanline: string
    while r < scanlines:
        let filter = Filter(buf.readUint8)
        # read the scanline so we can unapply filters before reading colors
        var scanline = newString(img.width * img.bpp)
        for i in 0..<img.width * img.bpp:
            scanline[i] = buf.readChar
        filter.unapply(img.bpp, scanline, last_scanline)
        var scanBuf = newStringStream(scanline)
        var c = 0
        while c < img.width:
            var color: NColor
            case img.colorType
            of gray:
                color = scanBuf.read_gray()
            of graya:
                color = scanBuf.read_graya()
            of rgb:
                color = scanBuf.read_rgb()
            of rgba:
                color = scanBuf.read_rgba()
            of palette:
                color = scanBuf.read_palette(img)
            img[r, c] = color
            c += 1
        last_scanline = scanline
        r += 1

proc load_plte(img: PngImage, chunkData: string): int =
    let colors = int(chunkData.len / 3)
    assert(colors * 3 == chunkData.len)
    var buf = newStringStream(chunkData)
    for v in img.palette.mitems:
        if not buf.atEnd:
            v = read_rgb(buf)
        else:
            v = NColor(0)
    return colors

proc load_png*(buf: Stream): Image =
    var result: PngImage
    new(result)
    if buf.isNil:echo "Nilbuffer"
    for i in 0..<PNG_HEADER.len:
        if buf.atEnd:
            raise newException(
                ValueError, "file too short; only " & $i & " bytes long")
        var fheader = buf.readUint8
        if uint8(PNG_HEADER[i]) != fheader:
            raise newException(
                ValueError,
                "header bytes did not match at position " & $i &
                " header: " & $PNG_HEADER[i] & " file: " & $fheader)
    var idats: seq[string]
    while not buf.atEnd:
        let
            chunkLen = buf.readNInt32
            chunkType = uint32(buf.readNInt32)
        when DEBUG: echo("chunk type " & itostr(chunkType) & " len " & $chunkLen)
        let
            chunkData = buf.readStr(chunkLen)
            crc = uint32(buf.readNInt32)
            chunkCrc = zcrc(itostr(chunkType), chunkData)
        if crc != chunkCrc:
            raise newException(
                ValueError,
                "bad CRC; from file: " & crc.int.toHex(8) & ", from data: " & chunkCrc.int.toHex(8) )
        case chunkType
        of ifromstr("IHDR"):
            load_ihdr(result, chunkData)
            when DEBUG: echo("  after ihdr: " & $result)
        of ifromstr("PLTE"):
            when DEBUG:
                let colors = load_plte(result, chunkData)
                echo("  color count: " & $colors)
            else:
                discard load_plte(result, chunkData)
        of ifromstr("IDAT"):
            idats.add(chunkData)
        of ifromstr("IEND"):
            discard
        else:
            when DEBUG: echo("unknown chunk type " & itostr(chunkType))
    var idat_len = 0
    for v in idats:
        idat_len += v.len
    var idat = newString(idat_len)
    var last_i = 0
    for i, v in idats:
        copyMem(addr(idat[last_i]), addr(idats[i][0]), v.len)
        last_i += v.len
    load_idat(result, idat)
    when DEBUG:
        echo("loaded image " & $result)
    return result
