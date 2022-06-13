==========================================================
          packedjson2 - Yet another JSON library
==========================================================

packedjson2 is JSON library that implements the JSON Patch RFC which is specified in `RFC
6902 <https://datatracker.ietf.org/doc/html/rfc5789/>`_ from the IETF.

Documentation
=============

For more information visit: https://jsonpatch.com/ or the linked RFC documents.

JSON Pointer
------------

.. code-block:: nim

  type
    JsonPtr* = distinct string

JSON Pointer `(IETF RFC 6901) <https://datatracker.ietf.org/doc/html/rfc6901/>`_ defines a
string format for identifying a specific value within a JSON document. It is used by all
operations in JSON Patch to specify the part of the document to operate on.

A JSON Pointer is a string of tokens separated by ``/`` characters, these tokens either
specify keys in objects or indexes into arrays. For example, given the JSON

.. code-block:: json

  {
    "a": [1, 2, 3],
    "b": 4,
    "c": [5, 6],
    "d": {"e": [7, 8], "f": 9}
  }

``/d/e`` would point to the array of ints ``[7, 8]`` and ``/d/e/0`` would point to ``7``.

To point to the root of the document use an empty string for the pointer. The pointer
``/`` doesn’t point to the root, it points to a key of "" on the root (which is totally
valid in JSON).

If you need to refer to a key with ``~`` or ``/`` in its name, you must escape the
characters with ``~0`` and ``~1`` respectively. For example, to get ``"baz"`` from ``{
"foo/bar~": "baz" }`` you’d use the pointer ``/foo~1bar~0``.

Finally, if you need to refer to the end of an array you can use ``-`` instead of an
index. For example, to refer to the end of the array of biscuits above you would use
``/a/-``. This is useful when you need to insert a value at the end of an array.

Operations
----------

Add
^^^

.. code-block:: nim

  proc add*(x: var JsonTree; path: JsonPtr; value: JsonTree)

Adds a value to an object or inserts it into an array. In the case of an array, the value
is inserted before the given index. The ``-`` character can be used instead of an index to
insert at the end of an array.

Remove
^^^^^^

.. code-block:: nim

  proc remove*(x: var JsonTree; path: JsonPtr)

Removes a value from an object or array.

Replace
^^^^^^^

.. code-block:: nim

  proc replace*(x: var JsonTree; path: JsonPtr, value: JsonTree)

Replaces a value. Equivalent to a ``remove`` followed by an ``add``.

Copy
^^^^

.. code-block:: nim

  proc copy*(x: var JsonTree; `from`, path: JsonPtr)

Copies a value from one location to another within the JSON document. Both ``from`` and
``path`` are JSON Pointers.

Move
^^^^

.. code-block:: nim

  proc move*(x: var JsonTree; `from`, path: JsonPtr)

Moves a value from one location to the other. Both ``from`` and ``path`` are JSON Pointers.

Test
^^^^

.. code-block:: nim

  proc test*(x: JsonTree; path: JsonPtr, value: JsonTree): bool


Tests that the specified value is set in the document. If the test fails, then the patch
as a whole should not apply.

Misc
----

.. code-block:: nim

  # basic usage
  proc len*(x: JsonTree; path: JsonPtr): int
  proc kind*(x: JsonTree; path: JsonPtr): JsonNodeKind
  proc contains*(x: JsonTree; path: JsonPtr): bool
  proc extract*(x: JsonTree; path: JsonPtr): JsonTree
  # deserialize
  proc fromJson*[T](x: JsonTree; path: JsonPtr; t: typedesc[T]): T
  proc toJson*[T](x: T): JsonTree
  # iterators
  iterator items*(x: JsonTree; path: JsonPtr; t: typedesc[T]): T
  iterator pairs*(x: JsonTree; path: JsonPtr; t: typedesc[T]): (lent string, T)

Examples
========

.. code-block:: nim

  var x = %*{
    "a": [1, 2, 3],
    "b": 4,
    "c": [5, 6],
    "d": {"e": [7, 8], "f": 9}
  }

  # Basic usage
  assert len(x, JsonPtr"") == 4
  assert contains(x, JsonPtr"/a")
  assert kind(x, JsonPtr"/a") == JArray

  add x, JsonPtr"/a/-", %*[5, 6]
  # """{"a":[1,2,3,[5,6]],"b":4,"c":[5,6],"d":{"e":[7,8],"f":9}}"""

  remove x, JsonPtr"/d/e/1"
  # """{"a":[1,2,3,[5,6]],"b":4,"c":[5,6],"d":{"e":[7],"f":9}}"""

  replace x, JsonPtr"/b", %*"foo"
  # """{"a":[1,2,3,[5,6]],"b":"foo","c":[5,6],"d":{"e":[7],"f":9}}"""

  copy x, JsonPtr"/b", JsonPtr"/d/f"
  # """{"a":[1,2,3,[5,6]],"b":"foo","c":[5,6],"d":{"e":[7],"f":"foo"}}"""

  move x, JsonPtr"/c", JsonPtr"/b"
  # """{"a":[1,2,3,[5,6]],"b":[5,6],"d":{"e":[7],"f":"foo"}}"""

  # Comparing, copying, deserializing
  assert test(x, JsonPtr"/d", %*{"e": [7], "f": "foo"})
  assert $extract(x, JsonPtr"/d") == """{"e":[7,8],"f":9}"""
  assert fromJson(x, JsonPtr"/d/e", seq[int]) == @[7, 8]
  # Iterating
  for x items(x, JsonPtr"/a", int): echo x, " "
  # 1 2 3
  for k, v pairs(x, JsonPtr"/d", JsonTree): echo (k, v), " "
  # ("e", [7, 8]) ("f", 9)

Benchmarks
==========

Reading
-------

File: `benchmark.nim <bench/benchmark.nim>`_

+-------------+--------------+-----------+
| Library     | Used Mem     | Time      |
+=============+==============+===========+
| packedjson2 | 386.075MiB   | 2.82s     |
+-------------+--------------+-----------+
| packedjson  | **94.02MiB** | **2.0s**  |
+-------------+--------------+-----------+
| std/json    | 1.32GiB      | 3.07s     |
+-------------+--------------+-----------+

packedjson2  used Mem: 386.075MiB time: 2.82s
packed json  used Mem: 94.02MiB time: 2.0s
stdlib json  used Mem: 1.32GiB time: 3.07s

Adding
------

File: `benchmark5.nim <bench/benchmark5.nim>`_

+-------------+--------------+-----------+
| Library     | Used Mem     | Time      |
+=============+==============+===========+
| packedjson2 | 178.028MiB   | 1.67s     |
+-------------+--------------+-----------+
| packedjson  | **62.02MiB** | 2.56s     |
+-------------+--------------+-----------+
| std/json    | 1.32GiB      | **0.82s** |
+-------------+--------------+-----------+

TODO
====

#. Optimize further `#16 <https://github.com/planetis-m/packedjson2/issues/16>`_
#. Make ``test`` order independent `#24 <https://github.com/planetis-m/packedjson2/issues/24>`_
#. Implement all procs from `#7 <https://github.com/planetis-m/packedjson2/issues/7>`_
