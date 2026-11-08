import { partitionMathSources, MATH_LIMITS } from '../src/math-limits';
import type { MathSource } from '../src/math-syntax';
const item = (id: string, payload: string): MathSource => ({id,payload,raw:payload,display:true,firstLine:1,lastLine:1});

test('limits UTF-8 bytes, preserving valid mathematics after an oversized item', () => {
    const sources = [item('large','中'.repeat(22000)),item('good','x=1')];
    const result = partitionMathSources(sources);
    expect(result.accepted.map(source=>source.id)).toEqual(['good']);
    expect(result.rejected.map(source=>source.id)).toEqual(['large']);
});
test('accepts the exact per-expression boundary and rejects one byte more', () => {
    const result=partitionMathSources([item('exact','x'.repeat(MATH_LIMITS.expressionBytes)),item('over','x'.repeat(MATH_LIMITS.expressionBytes+1))]);
    expect(result.accepted.map(source=>source.id)).toEqual(['exact']);
});
test('bounds the total admitted item count', () => {
    const result=partitionMathSources(Array.from({length:5001},(_,i)=>item(String(i),'x')));
    expect(result.accepted).toHaveLength(5000);
    expect(result.rejected.map(source=>source.id)).toEqual(['5000']);
});
test('bounds accumulated bytes and retains the entire rejected tail', () => {
    const result=partitionMathSources(Array.from({length:34},(_,i)=>item(String(i),'x'.repeat(65536))));
    expect(result.accepted).toHaveLength(32);
    expect(result.rejected.map(source=>source.id)).toEqual(['32','33']);
});
