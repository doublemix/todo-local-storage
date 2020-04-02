const ul = document.getElementById("item-list");
const input = document.getElementById("new-item-input");

function simpleArrayObservable(inArray) {
  const ob = observable();
  let array = inArray.slice();
  return {
    remove(index) {
      array.splice(index, 1);
      ob.update(array);
    },
    unshift(item) {
      array.unshift(item);
      ob.update(array);
    },
    update(index, value) {
      array[index] = value;
      ob.update(array);
    },
    push(item) {
      array.push(item);
      ob.update(array);
    },
    moveItem(fromIndex, toIndex) {
      if (fromIndex === toIndex) return; // nothing to do
      const item = array[fromIndex];
      array.splice(fromIndex, 1);

      array.splice(toIndex, 0, item);
      ob.update(array);
    },
    set(newArray) {
      array = newArray.slice();
      ob.update(array);
    },
    clear() {
      array = [];
      ob.update(array);
    },
    refresh() {
      ob.update(array);
    },
    observe(observer) {
      ob.observe(observer);
      observer(array);
    }
  };
}

let itemsArray = simpleArrayObservable(
  localStorage.getItem("items") ? JSON.parse(localStorage.getItem("items")) : []
);
function loadItemsArray() {
  itemsArray.set(
    localStorage.getItem("items")
      ? JSON.parse(localStorage.getItem("items"))
      : []
  );
}

function liMaker(text, index) {
  const li = document.createElement("li");
  ul.appendChild(li);
  li.draggable = true;
  li.addEventListener("dragstart", function(ev) {
    ev.dataTransfer.setData("index", index);
  });
  li.addEventListener("dragover", function(ev) {
    ev.preventDefault();
  });
  li.addEventListener("drop", function(ev) {
    ev.preventDefault();
    const otherIndex = +ev.dataTransfer.getData("index");
    itemsArray.moveItem(otherIndex, index);
  });

  let editing = false;
  const textSpan = document.createElement("span");
  textSpan.textContent = text;
  textSpan.contentEditable = true;
  textSpan.addEventListener("keydown", function (event) {
    if (event.keyCode === 13) {
      event.preventDefault()
      if (textSpan.textContent.trim() !== '') {
        textSpan.blur()
      }
    }
  })
  textSpan.addEventListener("input", function (event) {
    editing = true;
    if (!li.classList.contains('editing')) {
      li.classList.add('editing')
    }
  })
  textSpan.addEventListener("blur", function (event) {
    if (editing) {
      const content = event.target.textContent.trim()
      if (content !== '') {
        itemsArray.update(index, content)
      } else {
        itemsArray.refresh()
      }
      li.classList.remove('editing')
      editing = false
    }
  })
  const removeSpan = document.createElement("span");
  removeSpan.addEventListener("click", function(event) {
    itemsArray.remove(index);
  });
  removeSpan.className = "remove-button";
  removeSpan.textContent = "X";

  li.appendChild(textSpan);
  li.appendChild(document.createTextNode(" "));
  li.appendChild(removeSpan);
}

input.addEventListener("keydown", function (event) {
  if (event.keyCode === 13) {
    event.preventDefault()
    // submit new item
    const content = input.textContent.trim()

    if (content !== "") {
      itemsArray.unshift(content);
      input.textContent = "";
      input.blur()
    }
  }
})

function observable() {
  let observers = [];
  return {
    observe(observer) {
      observers.push(observer);
      return function() {
        observers = observers.filter(iObserver => iObserver !== observer);
      };
    },
    update(arg) {
      observers.forEach(observer => observer(arg));
    }
  };
}

function arrayShallowEquals(this1, that1) {
  return (
    this1.length === that1.length &&
    this1.map((value, index) => value === that1[index]).indexOf(false) === -1
  );
}

itemsArray.observe(function(items) {
  while (ul.firstChild) {
    ul.removeChild(ul.firstChild);
  }
  items.forEach((item, index) => {
    liMaker(item, index);
  });
  const hist = localStorage.getItem("history")
    ? JSON.parse(localStorage.getItem("history"))
    : [];
  if (!arrayShallowEquals(hist[0] || [], items)) {
    hist.unshift(items);
    while (hist.length > 100) {
      hist.pop();
    }
    localStorage.setItem("history", JSON.stringify(hist));
  }
  localStorage.setItem("items", JSON.stringify(items));
});

window.addEventListener("storage", function(ev) {
  if (ev.key === "items") {
    loadItemsArray();
  }
});
window.addEventListener("focus", function(ev) {
  loadItemsArray();
});

loadItemsArray();

// Time Tracker Stuff

try {
  (function() {
    function runParser(value) {
      const valueTrimmed = value.trim();
      if (valueTrimmed === "") {
        timeTrackerResult.textContent = "";
        return;
      }
      try {
        const result = TimeTrackerParser.parse(value);
        timeTrackerResult.textContent = "Result: " + result;
      } catch (err) {
        timeTrackerResult.textContent = "Error: " + err.message;
      }
    }
    const timeTrackerInput = document.getElementById("time-tracker-query");
    const timeTrackerResult = document.getElementById("time-tracker-result");
    const initialValue = localStorage.getItem("timeTrackerQuery");
    if (initialValue !== null) {
      timeTrackerInput.value = initialValue;
      runParser(initialValue);
    }
    timeTrackerInput.addEventListener("input", function(event) {
      const value = timeTrackerInput.value;
      localStorage.setItem("timeTrackerQuery", value);
      runParser(value);
    });
  })();
} catch (err) {
  console.warn(err);
  // do nothing
}
