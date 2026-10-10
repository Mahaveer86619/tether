package main

import (
	"image"
	"image/color"
	"image/draw"
	"image/png"
	"math"
	"os"

	"golang.org/x/image/vector"
)

const k = 0.5522847498

var (
	top    = color.NRGBA{0xD4, 0x72, 0x4E, 0xFF}
	bottom = color.NRGBA{0xB0, 0x52, 0x33, 0xFF}
	cream  = color.NRGBA{0xFA, 0xF7, 0xEF, 0xFF}
)

func circle(r *vector.Rasterizer, cx, cy, rad float32) {
	r.MoveTo(cx+rad, cy)
	r.CubeTo(cx+rad, cy+rad*k, cx+rad*k, cy+rad, cx, cy+rad)
	r.CubeTo(cx-rad*k, cy+rad, cx-rad, cy+rad*k, cx-rad, cy)
	r.CubeTo(cx-rad, cy-rad*k, cx-rad*k, cy-rad, cx, cy-rad)
	r.CubeTo(cx+rad*k, cy-rad, cx+rad, cy-rad*k, cx+rad, cy)
	r.ClosePath()
}

func line(r *vector.Rasterizer, x1, y1, x2, y2, w float32) {
	dx, dy := x2-x1, y2-y1
	l := float32(math.Hypot(float64(dx), float64(dy)))
	nx, ny := -dy/l*w/2, dx/l*w/2
	r.MoveTo(x1+nx, y1+ny)
	r.LineTo(x2+nx, y2+ny)
	r.LineTo(x2-nx, y2-ny)
	r.LineTo(x1-nx, y1-ny)
	r.ClosePath()
}

func roundRect(r *vector.Rasterizer, x, y, w, h, rad float32) {
	r.MoveTo(x+rad, y)
	r.LineTo(x+w-rad, y)
	r.CubeTo(x+w-rad+rad*k, y, x+w, y+rad-rad*k, x+w, y+rad)
	r.LineTo(x+w, y+h-rad)
	r.CubeTo(x+w, y+h-rad+rad*k, x+w-rad+rad*k, y+h, x+w-rad, y+h)
	r.LineTo(x+rad, y+h)
	r.CubeTo(x+rad-rad*k, y+h, x, y+h-rad+rad*k, x, y+h-rad)
	r.LineTo(x, y+rad)
	r.CubeTo(x, y+rad-rad*k, x+rad-rad*k, y, x+rad, y)
	r.ClosePath()
}

// mark draws the tether symbol: a hub tethered to two devices, scaled by s
// around the canvas centre. Each shape is filled on its own so overlaps
// paint over each other instead of cancelling out.
func mark(dst *image.NRGBA, size, s float32, src image.Image) {
	n := int(size)
	c := size / 2
	p := func(x, y float32) (float32, float32) { return c + (x-512)*s*size/1024, c + (y-512)*s*size/1024 }
	u := s * size / 1024
	hx, hy := p(512, 640)
	lx, ly := p(300, 360)
	rx, ry := p(724, 360)
	shapes := []func(*vector.Rasterizer){
		func(r *vector.Rasterizer) { line(r, hx, hy, lx, ly, 46*u) },
		func(r *vector.Rasterizer) { line(r, hx, hy, rx, ry, 46*u) },
		func(r *vector.Rasterizer) { circle(r, hx, hy, 132*u) },
		func(r *vector.Rasterizer) { circle(r, lx, ly, 84*u) },
		func(r *vector.Rasterizer) { circle(r, rx, ry, 84*u) },
	}
	for _, shape := range shapes {
		r := vector.NewRasterizer(n, n)
		shape(r)
		fill(dst, r, src)
	}
}

func fill(dst *image.NRGBA, r *vector.Rasterizer, src image.Image) {
	mask := image.NewAlpha(dst.Bounds())
	r.Draw(mask, mask.Bounds(), image.Opaque, image.Point{})
	draw.DrawMask(dst, dst.Bounds(), src, image.Point{}, mask, image.Point{}, draw.Over)
}

func gradient(size int) *image.NRGBA {
	g := image.NewNRGBA(image.Rect(0, 0, size, size))
	for y := 0; y < size; y++ {
		t := float64(y) / float64(size-1)
		c := color.NRGBA{
			uint8(float64(top.R)*(1-t) + float64(bottom.R)*t),
			uint8(float64(top.G)*(1-t) + float64(bottom.G)*t),
			uint8(float64(top.B)*(1-t) + float64(bottom.B)*t), 0xFF,
		}
		for x := 0; x < size; x++ {
			g.SetNRGBA(x, y, c)
		}
	}
	return g
}

func save(name string, img image.Image) {
	f, err := os.Create(name)
	if err != nil {
		panic(err)
	}
	defer f.Close()
	if err := png.Encode(f, img); err != nil {
		panic(err)
	}
}

func icon(size int, full bool) *image.NRGBA {
	img := image.NewNRGBA(image.Rect(0, 0, size, size))
	fs := float32(size)
	if full {
		bg := vector.NewRasterizer(size, size)
		roundRect(bg, 0, 0, fs, fs, fs*0.225)
		fill(img, bg, gradient(size))
	}
	scale := float32(0.78)
	if !full {
		// Adaptive icons show only the centre ~61%; keep the mark inside it.
		scale = 0.5
	}
	mark(img, fs, scale, image.NewUniform(cream))
	return img
}

func main() {
	save("icon.png", icon(1024, true))
	save("icon_foreground.png", icon(1024, false))
	// Preview sheet at real launcher sizes.
	sheet := image.NewNRGBA(image.Rect(0, 0, 420, 140))
	draw.Draw(sheet, sheet.Bounds(), image.NewUniform(color.NRGBA{0xEE, 0xEC, 0xE6, 0xFF}), image.Point{}, draw.Src)
	x := 10
	for _, s := range []int{128, 96, 48, 32, 16} {
		ic := icon(s, true)
		draw.Draw(sheet, image.Rect(x, 6, x+s, 6+s), ic, image.Point{}, draw.Over)
		x += s + 14
	}
	save("preview.png", sheet)
}
