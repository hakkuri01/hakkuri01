# frozen_string_literal: true

# No gems needed. Run: ruby scripts/build.rb
# Adapted visual vocabulary and reveal timing from hakkuri01/nokizaru.
# The SVG contains declarative CSS animation, never executable scripts.
ROOT = File.expand_path('..', __dir__)
WIDTH = 960
HEIGHT = 560
CYCLE = 15.0
BOOT = 2.0
SETTLE = 1.4
FIRST_GLITCH = BOOT + CYCLE
FRAME_COUNT = 14
NOISE = '/\\|=+*%#<>[]'.chars.freeze
RED = '#d95c60'
CYAN = '#8ac5cd'
WHITE = '#d7d9df'
MUTED = '#92939f'
BG = '#0c0d11'

# Preserve every leading and trailing space in the supplied wordmark.
BANNER = File.readlines(File.join(ROOT, 'wordmark.md'), chomp: true).freeze
LOGOS = %w[ruby crystal javascript].to_h do |slug|
  source = File.read(File.join(ROOT, 'assets', 'logos', "#{slug}.svg"))
  [slug, source.scan(/<path\b[^>]*\/>/).join]
end.freeze

def escape(value)
  value.to_s.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;').gsub('"', '&quot;')
end

def text(x, y, value, color = WHITE, size = 15, attrs = '')
  %(<text x="#{x}" y="#{y}" fill="#{color}" font-size="#{size}" #{attrs}>#{escape(value)}</text>)
end

def line(x1, y1, x2, y2, color = RED, dashed = false)
  %(<path d="M#{x1} #{y1}H#{x2}" fill="none" stroke="#{color}" #{dashed ? 'stroke-dasharray="3 5" opacity=".4"' : ''}/>) if y1 == y2
end

def noise_text(value, y, elapsed, rng)
  return value unless elapsed

  intensity = [0.18, 0.42, 0.28, 0.5, 0.12, 0.38, 0.22, 0.3, 0.16, 0.25, 0.12, 0.08, 0.05, 0.02][[(elapsed * 10).round, 13].min]
  value.each_char.map { |char| char == ' ' || rng.rand >= intensity ? char : NOISE[rng.rand(NOISE.length)] }.join
end

def chrome
  # Deliberately asymmetric, mirrored HUD rails.
  [
    line(28, 28, 455, 28), line(455, 28, 728, 28, RED, true),
    line(28, 74, 504, 74), line(504, 74, 606, 74, RED, true),
    '<path d="M28 28V209 M932 375V532" stroke="#d95c60" fill="none"/>',
    '<path d="M28 209V320 M932 375V270" stroke="#d95c60" opacity=".35" stroke-dasharray="3 5"/>',
    # Vector branches share the exact spine coordinates, avoiding font bearings.
    '<path d="M28 52H60 M60 52L64 48L68 52L64 56Z M62 52L64 50L66 52L64 54Z" stroke="#d95c60" fill="none"/>',
    '<path d="M932 471H906 M906 471L902 467L898 471L902 475Z M904 471L902 469L900 471L902 473Z M932 496H906 M906 496L902 492L898 496L902 500Z M904 496L902 494L900 496L902 498Z" stroke="#d95c60" fill="none"/>',
    line(209, 532, 505, 532, RED, true), line(505, 532, 932, 532),
    line(341, 514, 466, 514, RED, true), line(466, 514, 932, 514),
    '<rect x="56" y="270" width="500" height="172" rx="2" fill="#101116" stroke="#333038"/>',
    '<rect x="576" y="270" width="328" height="172" rx="2" fill="#101116" stroke="#333038"/>',
    '<path d="M56 308H556 M576 308H904" stroke="#333038"/>',
    '<rect x="56" y="270" width="3" height="38" fill="#d95c60"/>',
    '<rect x="576" y="270" width="3" height="38" fill="#d95c60"/>',
    line(58, 245, 904, 245, '#333038')
  ].join
end

def frame(elapsed = nil, seed = 0, boot: nil)
  rng = Random.new(seed)
  rows = []
  add = lambda do |x, y, value, color = WHITE, size = 15, attrs = ''|
    rows << text(x, y, noise_text(value, y, elapsed, rng), color, size, attrs)
  end
  add.call(738, 33, '▰▰▱', RED, 16)
  add.call(88, 58, 'HAKKURI', RED, 18, 'font-weight="700" letter-spacing="2"')
  add.call(194, 58, '//', RED, 16)
  add.call(226, 58, 'PROFILE', WHITE, 14, 'letter-spacing="2"')
  add.call(615, 79, '▰▰▱', RED, 16)
  BANNER.each_with_index do |row, i|
    # Explicit cells prevent HTML whitespace collapsing, kerning or font fallback
    # advances from altering the supplied character grid. The source is unedited.
    positions = row.each_char.with_index.map { |_, col| format('%.4f', 67 + col * 10.8369140625) }.join(' ')
    add.call(positions, 117 + i * 20, row, RED, 18,
             'class="wordmark" xml:space="preserve" style="white-space:pre;font-kerning:none;font-variant-ligatures:none"')
  end
  command = boot ? 'whoami'[0, [[((boot - 0.3) / 0.12).floor, 0].max, 6].min] : 'whoami'
  add.call(59, 229, 'hakkuri@github', CYAN, 14)
  add.call(185, 229, ':~ $', MUTED, 14)
  add.call(230, 229, command, WHITE, 14)
  rows << %(<rect class="cursor" x="#{234 + command.length * 8.43}" y="217" width="8" height="14" fill="#{RED}"/>)
  add.call(74, 295, '01', RED, 12)
  add.call(108, 295, 'whoami', WHITE, 15)
  add.call(594, 295, '02', RED, 12)
  add.call(628, 295, 'stack', WHITE, 15)
  [[350, 'bug_bounty_hunter'], [402, 'aws_sec_ops']].each_with_index do |(y, role), i|
    next if boot && boot < 1.2 + i * 0.15
    add.call(75, y, '⟦+⟧', CYAN, 17)
    add.call(122, y, role, WHITE, 19)
  end
  [[338, 'Ruby', '#CC342D', 'ruby'], [380, 'Crystal', '#FFFFFF', 'crystal'], [422, 'JavaScript', '#F7DF1E', 'javascript']].each_with_index do |(y, name, color, slug), i|
    next if boot && boot < 1.5 + i * 0.15
    add.call(594, y, '⟦+⟧', CYAN, 15)
    rows << %(<use href="#logo-#{slug}" x="646" y="#{y - 17}" width="20" height="20" fill="#{color}" aria-label="#{name} logo"/>)
    add.call(688, y, name, WHITE, 17)
  end
  add.call(183, 537, '▱▰▰', RED, 16)
  add.call(309, 519, '▱▰▰', RED, 16)
  unless boot && boot < 1.9
    add.call(884, 477, 'PROFILE LOADED', MUTED, 12, 'letter-spacing="1" text-anchor="end"')
  end
  unless boot && boot < BOOT
    add.call(884, 502, 'IDLE', CYAN, 12, 'text-anchor="end"')
  end
  rows.join
end

def svg(body, css = '')
  <<~SVG
    <svg xmlns="http://www.w3.org/2000/svg" width="960" height="560" viewBox="0 0 960 560" role="img" aria-labelledby="title description">
    <title id="title">Hakkuri — security profile</title>
    <desc id="description">bug_bounty_hunter; aws_sec_ops. Stack: Ruby, Crystal, JavaScript. The whoami command populates the profile once, then text glitches every 15 seconds.</desc>
    <defs>#{LOGOS.map { |slug, paths| %(<symbol id="logo-#{slug}" viewBox="0 0 24 24">#{paths}</symbol>) }.join}</defs>
    <style>text{font-family:'DejaVu Sans Mono','Liberation Mono',Consolas,monospace}#{css}</style>
    <rect width="960" height="560" rx="8" fill="#{BG}"/>
    #{body}
    </svg>
  SVG
end

# The startup is one-shot. The first glitch begins 15 seconds after startup
# settles. Only text layers change; the HUD and table geometry never disappear.
css = +<<~CSS
  .transient{opacity:0;pointer-events:none}
  .ready{animation:ready #{BOOT}s steps(1,end) both}
  @keyframes ready{0%{opacity:0}100%{opacity:1}}
  .normal{animation:normal #{CYCLE}s steps(1,end) #{FIRST_GLITCH}s infinite}
  @keyframes normal{0%{opacity:0}#{SETTLE / CYCLE * 100}%,100%{opacity:1}}
  .cursor{animation:cursor 1.2s steps(1,end) infinite}
  @keyframes cursor{0%,49%{opacity:1}50%,100%{opacity:0}}
CSS

# Each frame is visible for exactly 100 ms. All values are generated from the
# timing constants so changing CYCLE also changes the CSS boundaries correctly.
def frame_css(name, index, duration, delay, repeats)
  first = index * 0.1 / duration * 100
  last = (index + 1) * 0.1 / duration * 100
  ".#{name}{animation:#{name} #{duration}s steps(1,end) #{delay}s #{repeats}}" \
    "@keyframes #{name}{#{index.zero? ? '' : '0%{opacity:0}'}#{first}%{opacity:1}#{last}%,100%{opacity:0}}"
end

boot_frames = (BOOT * 10).round.times.map do |i|
  css << frame_css("b#{i}", i, BOOT, 0, 1)
  %(<g class="transient b#{i}" aria-hidden="true">#{frame(boot: i / 10.0)}</g>)
end
loop_frames = FRAME_COUNT.times.map do |i|
  css << frame_css("f#{i}", i, CYCLE, FIRST_GLITCH, 'infinite')
  %(<g class="transient f#{i}" aria-hidden="true">#{frame(i / 10.0, i * 7919 + 17)}</g>)
end
css << '@media(prefers-reduced-motion:reduce){.transient{display:none!important}.ready,.normal,.cursor{animation:none!important;opacity:1!important}}'
base = frame
body = chrome + boot_frames.join + %(<g class="ready"><g class="normal">#{base}</g>#{loop_frames.join}</g>)
File.write(File.join(ROOT, 'assets/dashboard.svg'), svg(body, css))
File.write(File.join(ROOT, 'assets/dashboard-static.svg'), svg(chrome + base))

File.write(File.join(ROOT, 'preview.html'), <<~HTML)
  <!doctype html>
  <html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Hakkuri / profile preview</title>
  <style>
    *{box-sizing:border-box}body{margin:0;min-height:100vh;background:#08090c;color:#d7d9df;font:14px ui-monospace,monospace;display:grid;place-content:center;padding:24px}
    main{width:min(960px,calc(100vw - 48px))}.dashboard>svg{display:block;width:100%;height:auto;border:1px solid #27252c;border-radius:8px}
    footer{display:flex;gap:12px;align-items:center;flex-wrap:wrap;margin-top:18px;color:#92939f;font-size:12px}footer span{margin-right:auto}
    button{font:inherit;color:#d7d9df;background:#15151c;border:1px solid #40343c;border-radius:4px;padding:9px 14px;cursor:pointer}button:hover,button:focus-visible{border-color:#d95c60}
  </style>
  <main><div class="dashboard">#{File.read(File.join(ROOT, 'assets/dashboard.svg'))}</div>
  <footer><span>README asset preview · whoami startup / text glitch every 15s</span><button id="pause" aria-pressed="false">Pause</button><button id="replay">Replay</button></footer></main>
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

# GIF cannot play an intro once and loop only a later segment. Its fallback
# deliberately contains the recurring text glitch only. SVG/HTML have the intro.
if ARGV.include?('--frames')
  target = File.join(ROOT, 'frames')
  Dir.mkdir(target) unless Dir.exist?(target)
  FRAME_COUNT.times { |i| File.write(File.join(target, format('%02d.svg', i)), svg(chrome + frame(i / 10.0, i * 7919 + 17))) }
  File.write(File.join(target, '14.svg'), svg(chrome + base))
  [0.0, 0.7, 1.3, 1.6, 1.9].each do |t|
    File.write(File.join(target, "boot-#{t}.svg"), svg(chrome + frame(boot: t)))
  end
end
puts 'Built SVGs and HTML: one-shot whoami startup, then text-only glitches every 15 seconds.'
