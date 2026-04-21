import strftime from 'strftime';
import config from '../../config/formats.json';

/**
 * Format a date using the shared format from config/formats.json
 * @param {Date|string} date - Date object or ISO date string
 * @returns {string} Formatted date string
 */
export function formatDate(date) {
  const d = typeof date === 'string' ? new Date(date) : date;
  return strftime(config.dateFormat, d);
}
