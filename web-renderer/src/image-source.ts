/** Only a document-relative source is suitable for replacing an embedded image. */
export function relativeImageSource(source: string | null): string | undefined {
    if (!source || source !== source.trim() || /^(?:[a-z][a-z\d+.-]*:|\/|#)/i.test(source)) return undefined;
    return source;
}
