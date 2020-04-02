const form = document.getElementById("form");
const ul = document.getElementById("item-list");
const input = document.getElementById("item");
const listNameEl = document.getElementById('list-name');
const nameInput = document.getElementById('list-name-input');
const availableListsSelect = document.getElementById('available-lists');

const { useState, useEffect, useRef, createCustomHook } = hookedIn

const useEventListener = createCustomHook(
  'EventListener',
  function (target, eventName, handler, otherDeps) {
    let deps
    if (!(otherDeps instanceof Array)) {
      deps = undefined
    } else {
      deps = [target, eventName, ...otherDeps]
    }
    
    useEffect(
      function () {
        target.addEventListener(eventName, handler)
        
        return () => {
          target.removeEventListener(eventName, handler)
        }
      },
      deps,
    )
  },
)

const useLocalStorage = createCustomHook(
  'LocalStorage',
  function useLocalStorage (storageKey, initialValue = null) {
    const [value, setValue] = useState(() => {
      let storedJson = localStorage.getItem(storageKey)
      if (storedJson === null) {
        if (typeof initialValue === 'function') {
          initialValue = initialValue()
        }
        storedJson = JSON.stringify(initialValue)
        localStorage.setItem(storageKey, storedJson)
      }
      return JSON.parse(storedJson)
    })
    
    const setLocalStorageValue = (newValue) => {
      setValue(oldValue => {
        const newJson = JSON.stringify(newValue)
        const oldJson = JSON.stringify(oldValue)
        
        if (newJson === oldJson) {
          // no update
          return oldValue
        }
        
        localStorage.setItem(storageKey, newJson)
        
        return JSON.parse(newJson)
      })
    }
    
    useEventListener(window, 'storage', function (ev) {
      if (ev.key === storageKey) {
        setValue(JSON.parse(localStorage.getItem(storageKey)))
      }
    }, [storageKey])
    
    useEventListener(window, 'focus', function (ev) {
      setValue(JSON.parse(localStorage.getItem(storageKey)))
    }, [storageKey])
    
    return [value, setLocalStorageValue]
  },
)

const useControlledInput = function (inputEl, value, onChange) {
  useEffect(function () {
    inputEl.value = value
  }, [value])
  
  useEventListener(inputEl, 'input', function (event) {
    onChange(event.target.value)
  }, [])
}

hookedIn(function () {
  const [currentList, setCurrentList] = useLocalStorage("todoList::currentList", () => {
    return uuid()
  })
  
  const [availableLists, setAvailableLists] = useLocalStorage("todoList::availableLists", () => {
    return [currentList]
  })
  
  const itemsListKey = currentList === null ? 'todoList::items--null' : `todoList::items--${currentList}`
  const historyKey = currentList === null ? 'todoList::history--null' : `todoList::history--${currentList}`
  const listNameKey = currentList === null ? 'todoList::items-name--null' : `todoList::items-name--${currentList}`
  
  const [itemsList, setItemsList] = useLocalStorage(itemsListKey, () => [])
  const [historyList, setHistory] = useLocalStorage(historyKey, () => [])
  const [listName, setListName] = useLocalStorage(listNameKey, () => `New List ${currentList}`)
  
  useControlledInput(nameInput, listName, (newListName) => {
    setListName(newListName)
  })
  
  const addHistoryItem = (newItem) => {
    setHistory([newItem, ...historyList.slice(0, 99)])
  }
  
  const addItem = (index, item) => {
    const newItemsList = [...itemsList.slice(0, index), item, ...itemsList.slice(index)]
    addHistoryItem(newItemsList)
    setItemsList(newItemsList)
  }
  
  const removeItem = (index) => {
    const newItemsList = [...itemsList.slice(0, index), ...itemsList.slice(index + 1)]
    addHistoryItem(newItemsList)
    setItemsList(newItemsList)
  }
  
  const updateItem = (index, value) => {
    const newItemsList = itemsList.slice()
    newItemsList[index] = value
    addHistoryItem(newItemsList)
    setItemsList(newItemsList)
  }
  
  const moveItem = (fromIndex, toIndex) => {
    if (fromIndex === toIndex) return; // nothing to do
    const newItemsList = itemsList.slice()
    const item = newItemsList[fromIndex];
    newItemsList.splice(fromIndex, 1);

    newItemsList.splice(toIndex, 0, item);
    addHistoryItem(newItemsList);
    setItemsList(newItemsList);
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
      moveItem(otherIndex, index);
    });

    const textSpan = document.createElement("span");
    textSpan.textContent = text;
    let editing = false;
    textSpan.addEventListener("click", function() {
      if (editing) return;
      editing = true;
      const input = document.createElement("input");
      input.type = "text";
      input.value = text;
      input.style.width = (textSpan.offsetWidth + 3).toString() + "px";
      input.addEventListener("blur", function() {
        updateItem(index, input.value);
        editing = false;
      });
      setTimeout(function() {
        input.focus();
      }, 1);

      while (textSpan.firstChild) {
        textSpan.removeChild(textSpan.firstChild);
      }
      textSpan.appendChild(input);
    });
    const removeSpan = document.createElement("span");
    removeSpan.addEventListener("click", function(event) {
      removeItem(index);
    });
    removeSpan.className = "remove-button";
    removeSpan.textContent = "X";

    li.appendChild(textSpan);
    li.appendChild(document.createTextNode(" "));
    li.appendChild(removeSpan);
  }

  useEffect.withName('Set List Name', () => {
    listNameEl.textContent = listName
  }, [listName])
  
  useEffect.withName('Generate List Items', () => {
    itemsList.forEach((item, index) => {
      liMaker(item, index, itemsList);
    });
    
    return () => {
      while (ul.firstChild) {
        ul.removeChild(ul.firstChild);
      }
    }
  }, [itemsList])
  
  useEventListener.withName('Submit New Item', form, 'submit', (e) => {
    e.preventDefault();

    addItem(0, input.value);
    input.value = "";
  }, [addItem])
  
  useEffect.withName('list select options', function () {
    availableLists.forEach(function (name) {
      const option = document.createElement('option')
      option.appendChild(document.createTextNode(JSON.parse(localStorage.getItem(`todoList::items-name--${currentList}`))))
      option.value = name
      availableListsSelect.appendChild(option)
    })
    availableListsSelect.value = selectedProfile
    return function () {
      while (availableListsSelect.firstChild) {
        availableListsSelect.removeChild(availableListsSelect.firstChild)
      }
    }
  }, [availableLists, currentList])
  
  // TODO fix problem in hookedIn where not passing dependencies doesn't cause rerender everytime
});
loadItemsArray();
