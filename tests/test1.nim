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

import nimage
import streams

proc main() =
    var buf3 = newFileStream("tests/bttf-palette.png", fmRead)
    let img3 = load_png(buf3)
    assert($img3[0, 0] == "010601FF")
    buf3.close()

    var buf2 = newFileStream("tests/bttf.png", fmRead)
    let img2 = load_png(buf2)
    buf2.close()
    var out2 = newFileStream("/tmp/bttf.png", fmWrite)
    let opts = new_opts(ColorType.rgb)
    img2.save_png(out2, opts)
    out2.close()

    var buf1 = newFileStream("tests/test1.png", fmRead)
    let img1 = load_png(buf1)
    assert($img1[0, 0] == "3C3C3CFF")
    buf1.close()
    var out1 = newFileStream("/tmp/xkcd.png", fmWrite)
    img1.save_png(out1)
    out1.close()

    echo("Success.")

when isMainModule:
    main()
