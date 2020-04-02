{
  const pad = (str, minWidth, char) => {
    let workStr = `${str}`;
    while (workStr.length < minWidth) {
      workStr = `${char}${workStr}`
    }
    return workStr
  }
  const formatTime = (mins) => {
    const isNegative = mins < 0;
    const absMins = Math.abs(mins);
    const hrPart = Math.floor(absMins / 60);
    const minPart = absMins % 60;

    const absTimeStr = `${hrPart}:${pad(`${minPart}`, 2, '0')}`;
    const timeStr = isNegative ? `(${absTimeStr})` : absTimeStr;

    return timeStr;
  }
  const format = (val) => {
    switch (val.units) {
      case 'mins': return formatTime(val.value)
      case 'scalar': return val.value.toString()
    }
  }

  const op = (unitCheck, unitCheckErrorMessage, units, resolve) => (x, y = {}) => {
    if (!unitCheck(x.units, y.units)) {
      throw new Error(unitCheckErrorMessage(x.units, y.units))
    }
    return {
      units: units(x.units, y.units),
      value: resolve(x.value, y.value),
    }
  }
  const MUL_MAP = [
    ['scalar', 'mins', 'mins'],
    ['scalar', 'scalar', 'scalar'],
    ['mins', 'scalar', 'mins'],
  ]
  const lookup = (map, one, two, oneCol = 0, twoCol = 1, outputCol = 2) => {
    const index = map.findIndex(x => x[oneCol] === one && x[twoCol] === two)
    return index >= 0 ? map[index][outputCol] : null
  }
  const pos = op(
    () => true,
    () => '',
    x => x,
    x => x
  )
  const neg = op(
    () => true,
    () => '',
    x => x,
    x => -x,
  )
  const add = op(
    (x, y) => x === y,
    (x, y) => `Cannot add ${x} to ${y}`,
    (x, y) => x,
    (x, y) => x + y,
  )
  const sub = op(
    (x, y) => x === y,
    (x, y) => `Cannot sub ${y} from ${x}`,
    (x, y) => x,
    (x, y) => x - y,
  )
  const mul = op(
    (x, y) => lookup(MUL_MAP, x, y) !== null,
    (x, y) => `Cannout mul ${x} with ${y}`,
    (x, y) => lookup(MUL_MAP, x, y),
    (x, y) => x * y,
  )
  const div = op(
    (x, y) => lookup(MUL_MAP, x, y, 2, 0, 1) !== null,
    (x, y) => `Cannot div ${x} by ${y}`,
    (x, y) => lookup(MUL_MAP, x, y, 2, 0, 1),
    (x, y) => x / y,
  )
}

Main
  = _ ex:Expression _ {
    return format(ex)
  }

Expression
  = head:Term tail:(_ op:("+" / "-") _ term:Term { return { term, op } })* {
      return tail.reduce(function(result, element) {
        if (element.op === "+") { return add(result, element.term); }
        if (element.op === "-") { return sub(result, element.term); }
      }, head);
    }

Term
  = head:Factor tail:(_ ("*" / "/") _ Factor)* {
      return tail.reduce(function(result, element) {
        if (element[1] === "*") { return mul(result, element[3]); }
        if (element[1] === "/") { return div(result, element[3]); }
      }, head);
    }

Factor
  = "(" _ expr:Expression _ ")" { return expr; }
  / "+" _ expr:Factor { return pos(expr) }
  / "-" _ expr:Factor { return neg(expr) }
  / Time
  / Integer

Time
 = hrs:INT ':' mins:INT {
   return { units: 'mins', value: hrs * 60 + mins };
 }

Integer "integer"
  = value:INT { return { units: 'scalar', value }; }

INT
  = [0-9]+ { return parseInt(text(), 10) }

_ "whitespace"
  = [ \t\n\r]*

