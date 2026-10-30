// Recursive-descent arithmetic parser. Never evaluates JavaScript.
export function calculate(expression: string): string {
  if (expression.length > 150) throw new Error('Expression too long');
  const input = expression.replace(/×/g, '*').replace(/÷/g, '/').replace(/−/g, '-').replace(/\s/g, '');
  let position = 0;
  const peek = () => input[position];
  function primary(): number {
    let result: number;
    if (peek() === '+') { position++; return primary(); }
    if (peek() === '-') { position++; return -primary(); }
    if (peek() === '(') {
      position++; result = sum();
      if (peek() !== ')') throw new Error('Close the bracket');
      position++;
    } else {
      const match = input.slice(position).match(/^(?:\d+(?:\.\d*)?|\.\d+)(?:e[+-]?\d+)?/i);
      if (!match) throw new Error('Enter a number');
      position += match[0].length;
      result = Number(match[0]);
    }
    while (peek() === '%') { position++; result /= 100; }
    return result;
  }
  function product(): number {
    let value = primary();
    while (peek() === '*' || peek() === '/') {
      const operator = input[position++], next = primary();
      if (operator === '/' && next === 0) throw new Error('Cannot divide by zero');
      value = operator === '*' ? value * next : value / next;
    }
    return value;
  }
  function sum(): number {
    let value = product();
    while (peek() === '+' || peek() === '-') {
      const operator = input[position++], next = product();
      value = operator === '+' ? value + next : value - next;
    }
    return value;
  }
  const result = sum();
  if (position !== input.length) throw new Error('Check your expression');
  if (!Number.isFinite(result)) throw new Error('Result is too large');
  return String(Number(result.toPrecision(12)));
}
