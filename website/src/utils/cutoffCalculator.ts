export enum CutoffState { normal, nearDeadline, dueToday, justPassed }

export interface CutoffInfo {
  state: CutoffState;
  daysUntilNext: number;
  daysSincePrev: number;
  nextCutoffDay: number;
  prevCutoffDay: number | null;
  statusText: string;
  statusColor: string;
}

const nearWindowDays = 3;
const overdueWindowDays = 7;

function sortedCutoffs(day1: number, day2: number): number[] {
  return [day1, day2].sort((a, b) => a - b);
}

function daysBetween(from: Date, to: Date): number {
  const msPerDay = 24 * 60 * 60 * 1000;
  return Math.round((to.getTime() - from.getTime()) / msPerDay);
}

function daysLabel(n: number, suffix: string): string {
  const plural = n === 1 ? "day" : "days";
  if (suffix === "") return `${n} ${plural}`;
  if (suffix === "days") return `${n} ${plural}`;
  return `${n} ${plural} ${suffix}`;
}

export function cutoffStatusText(info: CutoffInfo): string {
  switch (info.state) {
    case CutoffState.dueToday:
      return "Due today";
    case CutoffState.nearDeadline:
      return daysLabel(info.daysUntilNext, "until cutoff");
    case CutoffState.justPassed:
      return `Overdue by ${daysLabel(info.daysSincePrev, "")}`.trim();
    case CutoffState.normal:
      return `Next cutoff in ${daysLabel(info.daysUntilNext, "days")}`;
  }
}

export function cutoffStatusColor(info: CutoffInfo): string {
  switch (info.state) {
    case CutoffState.dueToday:
      return "#ef4444";
    case CutoffState.nearDeadline:
      return "#f59e0b";
    case CutoffState.justPassed:
      return "#f97316";
    case CutoffState.normal:
      return "#22c55e";
  }
}

export function computeCutoff(
  now: Date,
  cutoffDay1: number,
  cutoffDay2: number,
): CutoffInfo {
  const cutoffs = sortedCutoffs(cutoffDay1, cutoffDay2).filter((c) => c > 0);
  const today = now.getDate();

  if (cutoffs.length === 0) {
    return {
      state: CutoffState.normal,
      daysUntilNext: 0,
      daysSincePrev: 0,
      nextCutoffDay: 0,
      prevCutoffDay: null,
      statusText: "No cutoff set",
      statusColor: "#22c55e",
    };
  }

  let nextCutoff: number | null = null;
  let prevCutoff: number | null = null;
  for (const c of cutoffs) {
    if (c >= today) {
      nextCutoff = c;
      break;
    }
    prevCutoff = c;
  }

  let daysUntilNext: number;
  let nextCutoffDay: number;
  if (nextCutoff === null) {
    nextCutoffDay = cutoffs[0];
    const nextMonth = new Date(now.getFullYear(), now.getMonth() + 1, nextCutoffDay);
    const todayDate = new Date(now.getFullYear(), now.getMonth(), today);
    daysUntilNext = daysBetween(todayDate, nextMonth);
  } else {
    nextCutoffDay = nextCutoff;
    daysUntilNext = nextCutoff - today;
  }

  const daysSincePrev = prevCutoff !== null ? today - prevCutoff : 0;

  let state: CutoffState;
  if (daysUntilNext === 0) {
    state = CutoffState.dueToday;
  } else if (daysSincePrev > 0 && daysSincePrev <= overdueWindowDays) {
    state = CutoffState.justPassed;
  } else if (daysUntilNext <= nearWindowDays) {
    state = CutoffState.nearDeadline;
  } else {
    state = CutoffState.normal;
  }

  const info: CutoffInfo = {
    state,
    daysUntilNext,
    daysSincePrev,
    nextCutoffDay,
    prevCutoffDay: prevCutoff,
    statusText: "",
    statusColor: "",
  };
  info.statusText = cutoffStatusText(info);
  info.statusColor = cutoffStatusColor(info);
  return info;
}
