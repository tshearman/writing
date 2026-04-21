import { h } from 'preact';

export function SearchResult({ url, title, excerpt }) {
  return (
    <li className="search-result">
      <a href={url} className="search-result-link">
        <span className="search-result-title">{title}</span>
      </a>
      <p
        className="search-result-excerpt"
        dangerouslySetInnerHTML={{ __html: excerpt }}
      />
    </li>
  );
}

export function SearchResults({ results }) {
  return (
    <>
      {results.map((result, i) => (
        <SearchResult
          key={i}
          url={result.url}
          title={result.meta?.title || result.url}
          excerpt={result.excerpt || ''}
        />
      ))}
    </>
  );
}
