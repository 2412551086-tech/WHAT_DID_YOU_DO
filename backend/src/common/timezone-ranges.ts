export const DEFAULT_FAMILY_TIMEZONE = 'Asia/Shanghai';

type ZonedDateParts = {
  year: number;
  month: number;
  day: number;
  hour: number;
  minute: number;
  second: number;
};

const formatters = new Map<string, Intl.DateTimeFormat>();

export function isValidTimeZone(timezone: string): boolean {
  try {
    new Intl.DateTimeFormat('en-US', { timeZone: timezone }).format(new Date());
    return true;
  } catch {
    return false;
  }
}

export function normalizeTimeZone(timezone?: string | null): string {
  const normalized = timezone?.trim() || DEFAULT_FAMILY_TIMEZONE;
  return isValidTimeZone(normalized) ? normalized : DEFAULT_FAMILY_TIMEZONE;
}

export function getLocalDateKeyForTimeZone(date: Date, timezone: string): string {
  const parts = getZonedDateParts(date, normalizeTimeZone(timezone));
  return [parts.year, parts.month, parts.day]
    .map((part, index) => (index === 0 ? String(part) : String(part).padStart(2, '0')))
    .join('-');
}

export function getLocalHourForTimeZone(date: Date, timezone: string): number {
  return getZonedDateParts(date, normalizeTimeZone(timezone)).hour;
}

export function getDayRangeForTimeZone(timezone: string, now = new Date()) {
  const safeTimeZone = normalizeTimeZone(timezone);
  const parts = getZonedDateParts(now, safeTimeZone);

  return {
    start: zonedDateTimeToUtc(
      { year: parts.year, month: parts.month, day: parts.day, hour: 0, minute: 0, second: 0 },
      safeTimeZone,
    ),
    end: zonedDateTimeToUtc(
      { year: parts.year, month: parts.month, day: parts.day + 1, hour: 0, minute: 0, second: 0 },
      safeTimeZone,
    ),
  };
}

export function getWeekRangeForTimeZone(timezone: string, now = new Date(), weekOffset = 0) {
  const safeTimeZone = normalizeTimeZone(timezone);
  const parts = getZonedDateParts(now, safeTimeZone);
  const localDate = new Date(Date.UTC(parts.year, parts.month - 1, parts.day));
  const daysSinceMonday = (localDate.getUTCDay() + 6) % 7;
  const mondayDay = parts.day - daysSinceMonday + weekOffset * 7;

  return {
    start: zonedDateTimeToUtc(
      { year: parts.year, month: parts.month, day: mondayDay, hour: 0, minute: 0, second: 0 },
      safeTimeZone,
    ),
    end: zonedDateTimeToUtc(
      { year: parts.year, month: parts.month, day: mondayDay + 7, hour: 0, minute: 0, second: 0 },
      safeTimeZone,
    ),
  };
}

export function getMonthRangeForTimeZone(month: string, timezone: string) {
  const match = /^(\d{4})-(\d{2})$/.exec(month);

  if (!match) {
    throw new Error('Invalid month format');
  }

  const year = Number(match[1]);
  const monthNumber = Number(match[2]);

  if (monthNumber < 1 || monthNumber > 12) {
    throw new Error('Invalid month value');
  }

  const safeTimeZone = normalizeTimeZone(timezone);
  return {
    start: zonedDateTimeToUtc(
      { year, month: monthNumber, day: 1, hour: 0, minute: 0, second: 0 },
      safeTimeZone,
    ),
    end: zonedDateTimeToUtc(
      { year, month: monthNumber + 1, day: 1, hour: 0, minute: 0, second: 0 },
      safeTimeZone,
    ),
  };
}

function getZonedDateParts(date: Date, timezone: string): ZonedDateParts {
  const entries = formatter(timezone).formatToParts(date).map((part) => [part.type, part.value]);
  const parts = Object.fromEntries(entries);
  const hour = Number(parts.hour);

  return {
    year: Number(parts.year),
    month: Number(parts.month),
    day: Number(parts.day),
    hour: hour === 24 ? 0 : hour,
    minute: Number(parts.minute),
    second: Number(parts.second),
  };
}

function formatter(timezone: string) {
  const cached = formatters.get(timezone);

  if (cached) {
    return cached;
  }

  const created = new Intl.DateTimeFormat('en-US', {
    timeZone: timezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hourCycle: 'h23',
  });
  formatters.set(timezone, created);
  return created;
}

function zonedDateTimeToUtc(parts: ZonedDateParts, timezone: string): Date {
  const targetAsUtc = Date.UTC(parts.year, parts.month - 1, parts.day, parts.hour, parts.minute, parts.second);
  let utcMilliseconds = targetAsUtc;

  for (let index = 0; index < 4; index += 1) {
    const actualParts = getZonedDateParts(new Date(utcMilliseconds), timezone);
    const actualAsUtc = Date.UTC(
      actualParts.year,
      actualParts.month - 1,
      actualParts.day,
      actualParts.hour,
      actualParts.minute,
      actualParts.second,
    );

    const offset = actualAsUtc - targetAsUtc;
    if (offset === 0) {
      break;
    }

    utcMilliseconds -= offset;
  }

  return new Date(utcMilliseconds);
}
