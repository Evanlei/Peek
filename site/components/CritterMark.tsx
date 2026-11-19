import { COLS, ROWS, basePose, pixels, type Pose } from "@/lib/critter";

/** Static SVG of the Peek character — logo, feature illustrations. */
export function CritterMark({ size = 24, pose, className }: { size?: number; pose?: Partial<Pose>; className?: string }) {
  const px = pixels(basePose(pose));
  return (
    <svg
      width={size}
      height={(size * ROWS) / COLS}
      viewBox={`0 0 ${COLS} ${ROWS}`}
      shapeRendering="crispEdges"
      className={className}
      aria-hidden
    >
      {px.map(([c, r, color], i) => (
        <rect key={i} x={c} y={r} width={1.02} height={1.02} fill={color} />
      ))}
    </svg>
  );
}
