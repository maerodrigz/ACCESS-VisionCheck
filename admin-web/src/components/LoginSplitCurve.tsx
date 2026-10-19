/**
 * Full-viewport S-curve divider (160×100 ≈ 16:10) for even scaling on desktop.
 * Spine ≈ 60% width at top/bottom; G1-continuous join at mid-height (no cusp).
 */
const W = 160
const H = 100

/** Join point (mid-height); upper/lower cubics share tangent here. */
const JX = 87
const JY = 50
/** Last control of upper cubic (before join). */
const U2X = 92
const U2Y = 32
/** First control of lower cubic — mirrored through join for smooth tangent. */
const L1X = 2 * JX - U2X
const L1Y = 2 * JY - U2Y
const L2X = 95
const L2Y = 84

const SPINE =
  'M 96 0 ' +
  `C 96 15, ${U2X} ${U2Y}, ${JX} ${JY} ` +
  `C ${L1X} ${L1Y}, ${L2X} ${L2Y}, 96 100`

function spinePath(deltaX: number) {
  const d = deltaX
  return (
    'M ' +
    (96 + d) +
    ' 0 ' +
    'C ' +
    (96 + d) +
    ' 15, ' +
    (U2X + d) +
    ' ' +
    U2Y +
    ', ' +
    (JX + d) +
    ' ' +
    JY +
    ' C ' +
    (L1X + d) +
    ' ' +
    L1Y +
    ', ' +
    (L2X + d) +
    ' ' +
    L2Y +
    ', ' +
    (96 + d) +
    ' 100'
  )
}

function spineRibbon(deltaFar: number, deltaNear: number) {
  const f = deltaFar
  const n = deltaNear
  return (
    spinePath(f) +
    ' L ' +
    (96 + n) +
    ' 100 ' +
    ' C ' +
    (L2X + n) +
    ' ' +
    L2Y +
    ', ' +
    (L1X + n) +
    ' ' +
    L1Y +
    ', ' +
    (JX + n) +
    ' ' +
    JY +
    ' C ' +
    (U2X + n) +
    ' ' +
    U2Y +
    ', ' +
    (96 + n) +
    ' 15, ' +
    (96 + n) +
    ' 0 Z'
  )
}

const WHITE_REGION = `${SPINE} L ${W} ${H} L ${W} 0 Z`

export function LoginSplitCurve() {
  return (
    <svg
      className="login-shell__curve"
      viewBox={`0 0 ${W} ${H}`}
      preserveAspectRatio="none"
      aria-hidden
      focusable="false"
    >
      <path className="login-shell__curve-white" d={WHITE_REGION} />
      <path className="login-shell__curve-band login-shell__curve-band--outer" d={spineRibbon(2.6, 1.2)} />
      <path className="login-shell__curve-band login-shell__curve-band--inner" d={spineRibbon(1.2, 0.4)} />
      <path className="login-shell__curve-line login-shell__curve-line--soft" d={spinePath(0.55)} vectorEffect="non-scaling-stroke" />
      <path className="login-shell__curve-line login-shell__curve-line--cyan" d={spinePath(0.25)} vectorEffect="non-scaling-stroke" />
    </svg>
  )
}
