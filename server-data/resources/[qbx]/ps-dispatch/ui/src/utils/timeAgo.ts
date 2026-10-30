import { readable } from "svelte/store";

const MONTH_NAMES = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

function getFormattedDate(date, prefomattedDate = false, hideYear = false) {
  const day = date.getDate();
  const month = MONTH_NAMES[date.getMonth()];
  const year = date.getFullYear();
  const hours = date.getHours();
  let minutes = date.getMinutes();

  if (minutes < 10) {
      minutes = `0${minutes}`;
  }

  if (prefomattedDate) {
      return `${prefomattedDate} at ${hours}:${minutes}`;
  }

  if (hideYear) {
      return `${day}. ${month} at ${hours}:${minutes}`;
  }

      return `${day}. ${month} ${year}. at ${hours}:${minutes}`;
  }


export function timeAgo(dateParam) {
  if (!dateParam) {
  return 'Unknown';  
  }

  let date;
  try {
  date =  typeof dateParam === 'object' ? dateParam : new Date(dateParam);    
  } catch (e) {
  return 'Invalid date';
  }

  if (isNaN(date)) {
  return 'Invalid date';  
  }
  const DAY_IN_MS = 86400000;
  const today = new Date();
  const yesterday = new Date(today - DAY_IN_MS);
  const seconds = Math.round((today - date) / 1000);
  const minutes = Math.round(seconds / 60);
  const isToday = today.toDateString() === date.toDateString();
  const isYesterday = yesterday.toDateString() === date.toDateString();
  const isThisYear = today.getFullYear() === date.getFullYear();

  if (seconds < 5) {
      return 'Just Now';
  } else if (seconds < 60) {
      return `${seconds} Seconds ago`;
  } else if (seconds < 90) {
      return 'A minute ago';
  } else if (minutes < 60) {
      return `${minutes} Minutes ago`;
  } else if (isToday) {
      return getFormattedDate(date, 'Today');
  } else if (isYesterday) {
      return getFormattedDate(date, 'Yesterday');
  } else if (isThisYear) {
      return getFormattedDate(date, false, true);
  }

  return getFormattedDate(date);
}

// Reference-card time stamp: wall clock plus a terse age, "17:36 · now" /
// "16:50 · 2m". `now` ticks so the age stays current while a card sits open.
export const now = readable(Date.now(), (set) => {
  const t = setInterval(() => set(Date.now()), 15000);
  return () => clearInterval(t);
});

export function clockAndAge(dateParam, nowMs = Date.now()) {
  const date = new Date(dateParam);
  if (!dateParam || isNaN(date.getTime())) return '';
  const hh = String(date.getHours()).padStart(2, '0');
  const mm = String(date.getMinutes()).padStart(2, '0');
  const min = Math.floor((nowMs - date.getTime()) / 60000);
  const age = min < 1 ? 'now' : min < 60 ? `${min}m` : min < 1440 ? `${Math.floor(min / 60)}h` : `${Math.floor(min / 1440)}d`;
  return `${hh}:${mm} · ${age}`;
}
