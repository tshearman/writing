import { h, render } from 'preact';
import { SearchResults } from './SearchResult.jsx';

// Render search results into the DOM
export function renderSearchResults(results) {
  const container = document.getElementById('search-results');
  render(<SearchResults results={results} />, container);
}

// Clear search results
export function clearSearchResults() {
  const container = document.getElementById('search-results');
  render(null, container);
}
