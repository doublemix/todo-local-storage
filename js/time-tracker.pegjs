{
  Object.defineProperties(Array.prototype, {
    last: {
      configurable: true,
      enumerable: false,
      get () {
        return this[this.length - 1]
      }
    }
  })
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
  const formatDuration = (mins) => {
    const isNegative = mins < 0;
    const absMins = Math.abs(mins);
    const hrPart = Math.floor(absMins / 60);
    const minPart = absMins % 60;

    const absHourStr = hrPart > 0 ? `${hrPart}hr` : ''
    const absMinStr = minPart > 0 || hrPart === 0 ? `${minPart}min` : ''
    const absTimeStr = `${absHourStr}${absMinStr}`;
    const durationStr = isNegative ? `-${absTimeStr}` : absTimeStr;

    return durationStr;
  }
  function isClose(x, y, err = 1e-6) {
    return Math.abs(x - y) < err
  }
  function isVector (x) {
    return x instanceof Array
  }
  const format = (val) => {
    if (isVector(val)) {
      if (isClose(val[1], DURATION)) {
        return formatDuration(val[0])
      } else if (isClose(val[1], TIME)) {
        return formatTime(val[0])
      } else {
        return 'Unknown ' + val[0] + ',' + val[1]
      }
    }
    try { return val.toString() } catch { return val }
  }
  const SCALAR = -1
  const DURATION = 0
  const TIME = 1
  const VARIABLE = 'var'
  const varify = (source, operation) => {
    const [[name, ops], _] = source
    return [[name, [operation, ...ops]], VARIABLE]
  }
  const isVar = (x) => {
    return x[1] === VARIABLE
  }
  const unaryOp = (f, fVar) => {
    return (term) => {
      if (isVar(term)) {
        return varify(term, fVar())
      }
      if (isVector(term)) {
        return term.map(x => f(x))
      }
      return f(term)
    }
  }
  const binaryOp = (f, fVectors, vectorSupports, fVar, fVarR) => {
    const supported = it => vectorSupports instanceof Array && vectorSupports.includes(it)
    return (term1, term2) => {
      if (isVar(term1) && isVar(term2)) {
        throw new Error("Multiple vars not supported");
      }
      if (isVar(term1)) {
        if (!fVar) {
          throw new Error("Unsupported variable operation");
        }
        return varify(term1, fVar(term2))
      }
      if (isVar(term2)) {
        if (fVarR) {
          return varify(term2, fVarR(term1))
        }
        if (!fVar) {
          throw new Error("Unsupported variable operation");
        }
        return varify(term2, fVar(term1))
      }
      if (isVector(term1) && isVector(term2)) {
        if (fVectors instanceof Function) {
          return fVectors(term1, term2)
        }
        if (supported('pairwise')) {
          return term1.map((x, i) => f(x, term2[i]))
        }
        throw new Error("unable to apply operator to vectors")
      }
      if (isVector(term1)) {
        if (!supported("scalar")) {
          throw new Error("unable to apply operator to vector and scalar")
        }
        return term1.map(x => f(x, term2))
      }
      if (isVector(term2)) {
        if (!supported("scalar")) {
          throw new Error("unable to apply operator scalar and vector")
        }
        return term2.map(x => f(term1, x))
      }
      return f(term1, term2)
    }
  }
  const pos = unaryOp(x => x, () => (x) => x)
  const neg = unaryOp(x => -x, () => x => neg(x))
  const add = binaryOp((x, y) => x + y, undefined, ['pairwise'], y => z => sub(z, y))
  const sub = binaryOp((x, y) => x - y, undefined, ['pairwise'], y => z => add(z, y), y => z => sub(y, z))
  const mul = binaryOp((x, y) => x * y, undefined, ['scalar'], y => z => div(z, y))
  const div = binaryOp((x, y) => x / y, (xx, yy) => {
    const k = xx[0] / yy[0]
    if (xx.every((x, i) => isClose(yy[i] * k, x))) {
      return k
    }
    throw new Error('division failed')
  }, ['scalar'], y => z => mul(y, z), y => z => div(y, z))

  const vars = {}
}

Main
  = _ result:EquationList _ display:DisplayOpts _ !. {
    return display.map(formatter => formatter(result)).join('; ')
  }

DisplayOpts
  = opts:DisplayOpts_0? {
    return opts ?? [result => format(result)]
  }

DisplayOpts_0
  = '%%' opts:DisplayOpts_1 {
    return opts
  }

DisplayOpts_1
  = DisplayOpt+
  / x:DisplayString {
    return [x]
  }

DisplayOpt
  = id:Id ';'? {
    return () => id in vars ? `${id} = ${format(vars[id])}` : `${id} missing`
  }
  / '#' {
    return () => Object.keys(vars).map(k => {
      return `${k} = ${format(vars[k])}`
    }).join('; ')
  }
  / '$' {
    return result => format(result)
  }

DisplayString
  = '"' els:DisplayStringElement* '"' {
    return result => els.map(f => f(result)).join('')
  }

DisplayStringElement
  = '$' id:Id ';'? {
    return () => id in vars ? `${format(vars[id])}` : `$${id};`
  }
  / '$' '$' {
    return () => '$'
  }
  / '$@' {
    return result => format(result)
  }
  / cs:DisplayStringCharacter+ {
    const value = cs.join('')
    return () => value
  }

DisplayStringCharacter
  = ![$"] c:. { return c }
  / '""' { return '"' }

EquationList
  = e0:Equation eRest:Equation* {
    return [e0, ...eRest].last
  }

EQNL
  = (';' / '\n') [ \n\t]*

Equation
  = ex:Expression _ lhs:('=' _ x:Expression { return x })? _ EQNL {
    let result = ex
    if (lhs) {
      if (isVar(lhs)) {
        let temp = lhs
        lhs = ex
        ex = temp
      }
      if (!isVar(ex) || isVar(lhs)) {
        throw new Error("Invalid format")
      }
      const [[id, ops], __] = ex
      result = ops.reduce((val, op) => op(val), lhs)
      vars[id] = result
    }
    if (isVar(result)) {
      throw new Error("result is variable")
    }
    return result
  }

Expression
  = head:Term tail:(_ op:("+" / "-") _ term:Term { return { term, op } })* {
      return tail.reduce(function(result, element) {
        if (element.op === "+") { return add(result, element.term); }
        if (element.op === "-") { return sub(result, element.term); }
      }, head);
    }

Term
  = head:Factor tail:(_ op:("*" / "/") _ term:Factor { return { term, op } })* {
      return tail.reduce(function(result, element) {
        if (element.op === "*") { return mul(result, element.term); }
        if (element.op === "/") { return div(result, element.term); }
      }, head);
    }

Factor
  = "(" _ expr:Expression _ ")" { return expr; }
  / "+" _ expr:Factor { return pos(expr) }
  / "-" _ expr:Factor { return neg(expr) }
  / Time
  / value:Number duration:DurationRest? {
    if (duration) {
      return [duration(value), DURATION]
    }
    return value
  }
  / id:Id {
    if (id in vars) {
      return vars[id]
    }
    return [[id, []], VARIABLE] 
  }

DurationRest
  = HoursIndicator minutesObj:(Number MinutesIndicator)? {
    return x => {
      let base = x * 60
      if (minutesObj) {
        const [minutes] = minutesObj
        return base + minutes
      }
      return base
    }
  }
  / MinutesIndicator {
    return x => x
  }

HoursIndicator
  = 'hr' 's'? { return 'hr' }

MinutesIndicator
  = 'min' 's'? { return 'min' }

Time
 = hrs:INT ':' mins:INT opts:TimeOpts {
   return [((opts.isAm && hrs == 12 ? 0 : hrs) + (opts.isPm && hrs != 12 ? 12: 0)) * 60 + mins, opts.isDuration ? DURATION : TIME];
 }

TimeOpts
  = x:TimeOpts_0? {
    return x ?? {}
  }

TimeOpts_0
  = 'D' { return { isDuration: true } }
  / _ 'A' 'M'? { return { isAm: true } }
  / _ 'P' 'M'? { return { isPm: true } }

Number "Number"
  = FLOAT

Id
  = ID

ID
  = [a-zA-Z_][a-zA-Z0-9_]* {
    return text()
  }

FLOAT
  = [0-9]+ ('.' [0-9]+)? { return parseFloat(text()) }

INT
  = [0-9]+ { return parseInt(text()) }

_ "whitespace"
  = ([ \t] / Comment)*

Comment
  = '//' [^\n]* '\n'


