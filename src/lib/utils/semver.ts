/** SemVer precedence, including numeric alpha/beta identifiers. */
export const parseVersion = (value: string) => {
  const match = value
    .trim()
    .replace(/^v/i, "")
    .match(
      /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?$/,
    );
  if (!match) return null;
  const prerelease = match[4]?.split(".") ?? [];
  if (
    prerelease.some(
      (part) =>
        !part ||
        (/^\d+$/.test(part) && part.length > 1 && part.startsWith("0")),
    )
  )
    return null;
  return { core: match.slice(1, 4).map(Number), prerelease };
};

export const compareVersions = (a: string, b: string): number => {
  const left = parseVersion(a),
    right = parseVersion(b);
  if (!left || !right) return 0;
  for (let index = 0; index < 3; index++) {
    if (left.core[index] !== right.core[index])
      return left.core[index] - right.core[index];
  }
  if (!left.prerelease.length || !right.prerelease.length)
    return Number(!left.prerelease.length) - Number(!right.prerelease.length);
  for (
    let index = 0;
    index < Math.max(left.prerelease.length, right.prerelease.length);
    index++
  ) {
    const x = left.prerelease[index],
      y = right.prerelease[index];
    if (x === undefined || y === undefined)
      return Number(x !== undefined) - Number(y !== undefined);
    if (x === y) continue;
    const xn = /^\d+$/.test(x),
      yn = /^\d+$/.test(y);
    if (xn && yn) return x.length - y.length || (x < y ? -1 : 1);
    if (xn !== yn) return xn ? -1 : 1;
    return x < y ? -1 : 1;
  }
  return 0;
};
