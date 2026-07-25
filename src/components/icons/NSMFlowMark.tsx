interface NSMFlowMarkProps {
  width?: number | string;
  height?: number | string;
  size?: number | string;
  className?: string;
}

const NSMFlowMark = ({ width, height, size, className }: NSMFlowMarkProps) => {
  const resolvedWidth = width ?? size ?? 32;
  const resolvedHeight = height ?? size ?? 32;

  return (
    <svg
      width={resolvedWidth}
      height={resolvedHeight}
      className={className}
      viewBox="0 0 64 64"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      aria-hidden="true"
    >
      <rect width="64" height="64" rx="17" fill="#111827" />
      <path
        d="M13 33h6l4-14 7 28 6-30 5 16h10"
        stroke="#67E8F9"
        strokeWidth="5"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <circle cx="51" cy="33" r="3" fill="#A78BFA" />
    </svg>
  );
};

export default NSMFlowMark;
