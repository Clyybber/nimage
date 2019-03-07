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

import zip/zlib

proc zuncompress*(data: string): string =
    let
        zdata = cstring(data)
        size = data.len
    for mul in 2..6:
        # Need to use var for the size guess so we can take its address
        var unzip_size_guess = Ulongf((1 shl mul) * size)
        result = newString(int(unzip_size_guess)) #TODO: why is the var needed?
        # Warning! You can't use len(zdata) here, because the string can have null
        # bytes inside which cause an incorrect string length calculation.
        let res = zlib.uncompress(
            result,
            Pulongf(addr unzip_size_guess),
            zdata,
            Ulongf(size))
        if res == zlib.Z_OK:
            result.setLen(unzip_size_guess)
            return result
        if res != zlib.Z_BUF_ERROR:
            raise newException(ValueError, "zlib returned error " & $res)
    raise newException(ValueError, "decompress too large; grew by more than 64x")

proc zuncompress*(data: seq[uint8]): string =
    let size = data.len
    var zdata_str = newString(size)
    for i in 0..<size:
        zdata_str[i] = char(data[i])
    return zuncompress(zdata_str)

proc zcompress*(data: string): string =
    var resultSize = zlib.compressBound(Ulong(data.len))
    result.setLen(resultSize)
    let res = zlib.compress(
        result, Pulongf(addr resultSize), data, Ulongf(data.len))
    if res != zlib.Z_OK:
        raise newException(ValueError, "zlib returned error " & $res)
    result.setLen(resultSize)

proc zcrc*(data: varargs[string]): uint32 =
    var crc = crc32(Ulong(0), Pbytef(nil), Uint(0))
    for d in data:
        if d.len == 0:
            continue
        var datum = d
        crc = crc32(crc, PBytef(addr(datum[0])), Uint(datum.len))
    return uint32(crc)
