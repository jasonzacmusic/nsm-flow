import NSMFlowMark from "./NSMFlowMark";

const PRODUCT_INITIALS = "NSM";
const PRODUCT_WORDMARK = "Flow";
const PRODUCT_NAME = `${PRODUCT_INITIALS} ${PRODUCT_WORDMARK}`;

const NSMFlowLogo = ({
  width = 180,
  className,
}: {
  width?: number;
  height?: number;
  className?: string;
}) => {
  return (
    <div
      className={`flex items-center gap-2 ${className ?? ""}`}
      style={{ width }}
      aria-label={PRODUCT_NAME}
    >
      <NSMFlowMark size={Math.max(30, Math.round(width * 0.24))} />
      <div className="leading-none min-w-0">
        <div className="text-[0.68rem] tracking-[0.24em] font-semibold opacity-60">
          {PRODUCT_INITIALS}
        </div>
        <div className="text-xl tracking-tight font-bold">
          {PRODUCT_WORDMARK}
        </div>
      </div>
    </div>
  );
};

export default NSMFlowLogo;
