# frozen_string_literal: true

# No gems needed. Run: ruby scripts/build.rb
# Adapted visual vocabulary and reveal timing from hakkuri01/nokizaru
# The glitch is Jekyll // Hyde's static flicker: every element, 30 fps, peaking mid-burst
# The SVG contains declarative CSS animation, never executable scripts
ROOT = File.expand_path('..', __dir__)
WIDTH = 960
HEIGHT = 560
CYCLE = 7.0
BOOT = 2.0
FPS = 30
STEP = 1.0 / FPS
GLITCH = 0.5
# The flicker's final frame is the settled one, which the clean layer already draws
FRAME_COUNT = (GLITCH * FPS).round - 1
SETTLE = FRAME_COUNT * STEP
FIRST_GLITCH = BOOT + CYCLE
NOISE = '/\\|=+*%#<>[]'.chars.freeze
# Tokyo Night, Night variant
RED = '#f7768e'
FG = '#c0caf5'
FG_DARK = '#a9b1d6'
GREEN = '#9ece6a'
# terminal_black, Tokyo Night's border gray
GRAY = '#414868'
BG = '#1a1b26'
BG_DARK = '#16161e'
# DejaVu Sans Mono's advance, so glyphs keep a fixed cell grid in any fallback font
ADVANCE = 1233.0 / 2048
# Rail cells are dash periods (3 on, 5 off), so a broken rail keeps its dash phase
CELL_H = 8
CELL_V = 16

# Every stroke as [x1, y1, x2, y2, color, opacity, width]; an opacity marks a dashed rail
# Deliberately asymmetric, mirrored HUD rails; both clusters space their rail pair 18 apart
RAILS = [
  [28, 28, 455, 28, RED], [455, 28, 728, 28, RED, 0.4],
  [28, 46, 504, 46, RED], [504, 46, 606, 46, RED, 0.4],
  [28, 28, 28, 209, RED], [932, 375, 932, 532, RED],
  [28, 209, 28, 320, RED, 0.35], [932, 375, 932, 270, RED, 0.35],
  [209, 532, 505, 532, RED, 0.4], [505, 532, 932, 532, RED],
  [341, 514, 466, 514, RED, 0.4], [466, 514, 932, 514, RED],
  [56, 308, 556, 308, GRAY], [576, 308, 904, 308, GRAY],
  [58, 245, 904, 245, GRAY],
  [57.5, 270, 57.5, 308, RED, nil, 3], [577.5, 270, 577.5, 308, RED, nil, 3]
].freeze
# Status readouts on branches off the right spine; each branch arrives with its text
READOUTS = [[471, 'PROFILE LOADED', FG_DARK, 1.9, 'letter-spacing="1" '], [496, 'IDLE', GREEN, BOOT, '']].freeze
BOXES = [[56, 270, 500, 172], [576, 270, 328, 172]].freeze
BOX_RAILS = BOXES.flat_map do |x, y, w, h|
  [[x, y, x + w, y], [x + w, y, x + w, y + h], [x + w, y + h, x, y + h], [x, y + h, x, y]].map { |rail| rail << GRAY }
end.freeze

# Preserve every leading and trailing space in the supplied wordmark
BANNER = File.readlines(File.join(ROOT, 'wordmark.md'), chomp: true).freeze
# The wordmark's cell grid: DejaVu Sans Mono's 18px advance, 20px rows, the first row's top at 101
WORD_X = 67
WORD_Y = 101
WORD_W = ADVANCE * 18
WORD_H = 20
LOGOS = %w[ruby crystal javascript].to_h do |slug|
  source = File.read(File.join(ROOT, 'assets', 'logos', "#{slug}.svg"))
  [slug, source.scan(/<path\b[^>]*\/>/).join]
end.freeze

def escape(value)
  value.to_s.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;').gsub('"', '&quot;')
end

def num(value) = format('%.2f', value).sub(/\.?0+\z/, '')

def text(x, y, value, color = FG, size = 15, attrs = '')
  %(<text x="#{x}" y="#{y}" fill="#{color}" font-size="#{size}" #{attrs}>#{escape(value)}</text>)
end

# Explicit cell positions keep kerning and font fallback advances off the character grid
def cells(x, size, from, count) = (from...from + count).map { |col| format('%.4f', x + col * ADVANCE * size) }.join(' ')

def noise_text(value, intensity, rng)
  return value unless intensity.positive?

  value.each_char.map { |char| char == ' ' || rng.rand >= intensity ? char : NOISE.sample(random: rng) }.join
end

def stroke(d, color, opacity = nil, width = nil)
  dash = opacity ? %( opacity="#{opacity}" stroke-dasharray="3 5") : ''
  %(<path d="#{d}" fill="none" stroke="#{color}"#{dash}#{width ? %( stroke-width="#{width}") : ''}/>)
end

def segment(x1, y1, x2, y2) = y1 == y2 ? "M#{num(x1)} #{num(y1)}H#{num(x2)}" : "M#{num(x1)} #{num(y1)}V#{num(y2)}"

def diamond(x, y) = "M#{x - 4} #{y}L#{x} #{y - 4}L#{x + 4} #{y}L#{x} #{y + 4}Z M#{x - 2} #{y}L#{x} #{y - 2}L#{x + 2} #{y}L#{x} #{y + 2}Z"

def panels = BOXES.map { |x, y, w, h| %(<rect x="#{x}" y="#{y}" width="#{w}" height="#{h}" rx="2" fill="#{BG}"/>) }.join

def static?(intensity, rng) = rng && rng.rand < intensity

# Static glyphs on explicit positions, one element per style
def glyphs(list, color, size, opacity = nil)
  return '' if list.empty?

  xs, ys, chars = list.transpose
  %(<text x="#{xs.map { num(_1) }.join(' ')}" y="#{ys.map { num(_1) }.join(' ')}" fill="#{color}" font-size="#{size}"#{opacity ? %( opacity="#{opacity}") : ''}>#{escape(chars.join)}</text>)
end

# Rails and branch tips; under the flicker each rail cell and tip turns to static at the frame's intensity
def chrome(rails, nodes, intensity = 0.0, rng = nil)
  strokes = Hash.new { |hash, key| hash[key] = [] }
  noise = Hash.new { |hash, key| hash[key] = [] }
  rails.each do |x1, y1, x2, y2, color, opacity, width|
    across = y1 == y2
    length = across ? x2 - x1 : y2 - y1
    sign = length <=> 0
    at = ->(d) { across ? [x1 + sign * d, y1] : [x1, y1 + sign * d] }
    run = nil
    0.step(length.abs - 1, across ? CELL_H : CELL_V) do |from|
      to = [from + (across ? CELL_H : CELL_V), length.abs].min
      if static?(intensity, rng)
        strokes[[color, opacity, width]] << segment(*at.(run), *at.(from)) if run
        run = nil
        cx, cy = at.((from + to) / 2.0)
        noise[[color, opacity]] << [cx - 0.3 * 14, cy + 5, NOISE.sample(random: rng)]
      else
        run ||= from
      end
    end
    strokes[[color, opacity, width]] << segment(*at.(run), *at.(length.abs)) if run
  end
  nodes.each do |x, y|
    next strokes[[RED, nil, nil]] << diamond(x, y) unless static?(intensity, rng)

    noise[[RED, nil]] << [x - 0.3 * 14, y + 5, NOISE.sample(random: rng)]
  end
  strokes.map { |style, ds| stroke(ds.join(' '), *style) }.join +
    noise.map { |(color, opacity), list| glyphs(list, color, 14, opacity) }.join
end

# Drawn the way a terminal draws box drawing: each glyph a stroke flush with its cell, so the
# diagonals meet corner to corner and the underscores run along the line the diagonals end on
def wordmark(intensity = 0.0, rng = nil)
  strokes = []
  noise = []
  BANNER.each_with_index do |row, line|
    top = WORD_Y + line * WORD_H
    bottom = top + WORD_H
    row.each_char.with_index do |char, col|
      next if char == ' '

      left = num(WORD_X + col * WORD_W)
      right = num(WORD_X + (col + 1) * WORD_W)
      stroke = case char
               when '╱' then "M#{left} #{bottom}L#{right} #{top}"
               when '╲' then "M#{left} #{top}L#{right} #{bottom}"
               when '_' then "M#{left} #{bottom}H#{right}"
               else raise ArgumentError, "wordmark.md: no stroke for #{char.inspect}"
               end
      static?(intensity, rng) ? noise << [WORD_X + col * WORD_W, bottom - 4, NOISE.sample(random: rng)] : strokes << stroke
    end
  end
  %(<path d="#{strokes.join}" fill="none" stroke="#{RED}" stroke-width="1.4" stroke-linecap="round"/>) + glyphs(noise, RED, 18)
end

def clean_chrome
  boxes = BOXES.map { |x, y, w, h| %(<rect x="#{x}" y="#{y}" width="#{w}" height="#{h}" rx="2" fill="none" stroke="#{GRAY}"/>) }
  boxes.join + chrome(RAILS, []) + wordmark
end

def frame(intensity = 0.0, rng = nil, boot: nil)
  rows = []
  add = lambda do |x, y, value, color = FG, size = 15, attrs = ''|
    rows << text(x, y, noise_text(value, intensity, rng), color, size, attrs)
  end
  # A glyph-free element (a logo, the cursor block) becomes one static glyph instead
  static = ->(element, x, y, color, size) { static?(intensity, rng) ? text(x, y, NOISE.sample(random: rng), color, size) : element }
  add.call(738, 33, '▰▰▱', RED, 16)
  add.call(615, 51, '▰▰▱', RED, 16)
  # One prompt on one cell grid, so nothing drifts apart: hakkuri@github:~$ whoami
  command = boot ? 'whoami'[0, [[((boot - 0.3) / 0.12).floor, 0].max, 6].min] : 'whoami'
  add.call(cells(59, 14, 0, 14), 229, 'hakkuri@github', GREEN, 14)
  add.call(cells(59, 14, 14, 3), 229, ':~$', FG_DARK, 14)
  add.call(cells(59, 14, 18, command.length), 229, command, FG, 14) unless command.empty?
  cursor = num(59 + (18 + command.length) * ADVANCE * 14)
  rows << static.(%(<rect class="cursor" x="#{cursor}" y="217" width="8" height="14" fill="#{RED}"/>), cursor, 229, RED, 14)
  add.call(74, 295, '01', RED, 12)
  add.call(108, 295, 'whoami', FG, 15)
  add.call(594, 295, '02', RED, 12)
  add.call(628, 295, 'stack', FG, 15)
  [[350, 'bug_bounty_hunter'], [402, 'aws_sec_ops']].each_with_index do |(y, role), i|
    next if boot && boot < 1.2 + i * 0.15

    add.call(75, y, '⟦+⟧', GREEN, 17)
    add.call(122, y, role, FG, 19)
  end
  # Logos keep their brand colors
  [[338, 'Ruby', '#CC342D', 'ruby'], [380, 'Crystal', '#FFFFFF', 'crystal'], [422, 'JavaScript', '#F7DF1E', 'javascript']].each_with_index do |(y, name, color, slug), i|
    next if boot && boot < 1.5 + i * 0.15

    add.call(594, y, '⟦+⟧', GREEN, 15)
    rows << static.(%(<use href="#logo-#{slug}" x="646" y="#{y - 17}" width="20" height="20" fill="#{color}" aria-label="#{name} logo"/>), 650, y, color, 17)
    add.call(688, y, name, FG, 17)
  end
  add.call(183, 537, '▱▰▰', RED, 16)
  add.call(309, 519, '▱▰▰', RED, 16)
  READOUTS.each do |y, label, color, from, attrs|
    next if boot && boot < from

    rows << chrome([[932, y, 906, y, RED]], [[902, y]], intensity, rng)
    add.call(884, y + 6, label, color, 12, %(#{attrs}text-anchor="end"))
  end
  rows.join
end

# Jekyll // Hyde's flicker curve: static rises to half the cells at the midpoint, then falls off
def glitch_frame(index)
  rng = Random.new(index * 7919 + 17)
  intensity = (1 - ((index + 1) * 2.0 / (FRAME_COUNT + 1) - 1).abs) * 0.5
  chrome(BOX_RAILS + RAILS, [], intensity, rng) + wordmark(intensity, rng) + frame(intensity, rng)
end

def svg(body, css = '')
  <<~SVG
    <svg xmlns="http://www.w3.org/2000/svg" width="#{WIDTH}" height="#{HEIGHT}" viewBox="0 0 #{WIDTH} #{HEIGHT}" role="img" aria-labelledby="title description">
    <title id="title">Hakkuri: security profile</title>
    <desc id="description">bug_bounty_hunter; aws_sec_ops. Stack: Ruby, Crystal, JavaScript. The whoami command populates the profile once, then every element glitches every #{format('%g', CYCLE)} seconds.</desc>
    <defs>#{LOGOS.map { |slug, paths| %(<symbol id="logo-#{slug}" viewBox="0 0 24 24">#{paths}</symbol>) }.join}</defs>
    <style>text{font-family:'DejaVu Sans Mono','Liberation Mono',Consolas,monospace}#{css}</style>
    <rect width="#{WIDTH}" height="#{HEIGHT}" rx="8" fill="#{BG_DARK}"/>
    #{body}
    </svg>
  SVG
end

def pct(seconds, duration) = format('%.4f', seconds / duration * 100)

# Each frame is visible for exactly one step; every boundary derives from the timing constants
def frame_css(name, index, step, duration, delay, repeats)
  ".#{name}{animation:#{name} #{duration}s steps(1,end) #{delay}s #{repeats}}" \
    "@keyframes #{name}{#{index.zero? ? '' : '0%{opacity:0}'}#{pct(index * step, duration)}%{opacity:1}#{pct((index + 1) * step, duration)}%,100%{opacity:0}}"
end

# The startup is one-shot; the first glitch starts one cycle after it settles. The clean
# layers hide while a glitch frame shows; only the panel fills never change
# Never name an animation after a keyword such as normal: the shorthand reads it as a direction
css = +<<~CSS
  .transient{opacity:0;pointer-events:none}
  .ready{animation:ready #{BOOT}s steps(1,end) both}
  @keyframes ready{0%{opacity:0}100%{opacity:1}}
  .clean{animation:clean #{CYCLE}s steps(1,end) #{FIRST_GLITCH}s infinite}
  @keyframes clean{0%{opacity:0}#{pct(SETTLE, CYCLE)}%,100%{opacity:1}}
  .cursor{animation:cursor 1.2s steps(1,end) infinite}
  @keyframes cursor{0%,49%{opacity:1}50%,100%{opacity:0}}
CSS

boot_frames = (BOOT * 10).round.times.map do |i|
  css << frame_css("b#{i}", i, 0.1, BOOT, 0, 1)
  %(<g class="transient b#{i}" aria-hidden="true">#{frame(boot: i / 10.0)}</g>)
end
loop_frames = FRAME_COUNT.times.map do |i|
  css << frame_css("f#{i}", i, STEP, CYCLE, FIRST_GLITCH, 'infinite')
  %(<g class="transient f#{i}" aria-hidden="true">#{glitch_frame(i)}</g>)
end
css << '@media(prefers-reduced-motion:reduce){.transient{display:none!important}.ready,.clean,.cursor{animation:none!important;opacity:1!important}}'
base = frame
body = panels + %(<g class="clean">#{clean_chrome}</g>) + boot_frames.join +
       %(<g class="ready"><g class="clean">#{base}</g>#{loop_frames.join}</g>)
File.write(File.join(ROOT, 'assets/dashboard.svg'), svg(body, css))
File.write(File.join(ROOT, 'assets/dashboard-static.svg'), svg(panels + clean_chrome + base))

File.write(File.join(ROOT, 'preview.html'), <<~HTML)
  <!doctype html>
  <html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Hakkuri / profile preview</title>
  <style>
    *{box-sizing:border-box}body{margin:0;min-height:100vh;background:#0c0e14;color:#{FG};font:14px ui-monospace,monospace;display:grid;place-content:center;padding:24px}
    main{width:min(960px,calc(100vw - 48px))}.dashboard>svg{display:block;width:100%;height:auto;border:1px solid #292e42;border-radius:8px}
    footer{display:flex;gap:12px;align-items:center;flex-wrap:wrap;margin-top:18px;color:#{FG_DARK};font-size:12px}footer span{margin-right:auto}
    button{font:inherit;color:#{FG};background:#{BG};border:1px solid #414868;border-radius:4px;padding:9px 14px;cursor:pointer}button:hover,button:focus-visible{border-color:#{RED}}
  </style>
  <main><div class="dashboard">#{File.read(File.join(ROOT, 'assets/dashboard.svg'))}</div>
  <footer><span>README asset preview · whoami startup / every element glitches every #{format('%g', CYCLE)}s</span><button id="pause" aria-pressed="false">Pause</button><button id="replay">Replay</button></footer></main>
  <script>
    const pause = document.querySelector('#pause');
    const dashboard = document.querySelector('.dashboard');
    const original = dashboard.innerHTML;
    const animations = () => dashboard.getAnimations({subtree:true});
    pause.addEventListener('click', () => {
      const paused = pause.getAttribute('aria-pressed') !== 'true';
      animations().forEach(a => paused ? a.pause() : a.play());
      pause.setAttribute('aria-pressed', String(paused));
      pause.textContent = paused ? 'Resume' : 'Pause';
    });
    document.querySelector('#replay').addEventListener('click', () => {
      dashboard.innerHTML = original;
      pause.setAttribute('aria-pressed', 'false'); pause.textContent = 'Pause';
    });
  </script></html>
HTML

# GIF cannot play an intro once and loop only a later segment, so its fallback frames
# hold the recurring glitch only; SVG and HTML have the intro
if ARGV.include?('--frames')
  target = File.join(ROOT, 'frames')
  Dir.mkdir(target) unless Dir.exist?(target)
  FRAME_COUNT.times { |i| File.write(File.join(target, format('%02d.svg', i)), svg(panels + glitch_frame(i))) }
  File.write(File.join(target, format('%02d.svg', FRAME_COUNT)), svg(panels + clean_chrome + base))
  [0.0, 0.7, 1.3, 1.6, 1.9].each do |t|
    File.write(File.join(target, "boot-#{t}.svg"), svg(panels + clean_chrome + frame(boot: t)))
  end
end
puts "Built SVGs and HTML: one-shot whoami startup, then every element glitches every #{format('%g', CYCLE)} seconds."
