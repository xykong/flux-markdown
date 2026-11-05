'use strict';
// Fixed campaign identifiers, never a person or an arbitrary redirect destination.
const ids = new URLSearchParams(location.search).getAll('u');
if (ids.length === 1 && ids[0] === '1001') location.replace('https://t.xykong.cc/p/1001');
