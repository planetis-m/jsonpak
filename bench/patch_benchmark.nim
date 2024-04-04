import std/[times, strutils, random, options]
import jsonpak, jsonpak/[patch, jsonptr, builder, mapper]

const iterations = 10_000

type
  User = object
    id: int
    name: string
    email: string

  Post = object
    id: int
    title: string
    content: string

  BlogData = object
    users: seq[User]
    posts: seq[Post]

proc generateBlogData(numUsers, numPosts: int): BlogData =
  var users = newSeq[User](numUsers)
  var posts = newSeq[Post](numPosts)
  for i in 0..<numUsers:
    users[i] = User(
      id: i + 1,
      name: "User " & $(i + 1),
      email: "user" & $(i + 1) & "@example.com"
    )
  for i in 0..<numPosts:
    posts[i] = Post(
      id: i + 1,
      title: "Post " & $(i + 1),
      content: "Lorem ipsum dolor sit amet, consectetur adipiscing elit."
    )
  result = BlogData(users: users, posts: posts)

var
  blogData = generateBlogData(100, 200)

proc findUser(id: int): Option[User] =
  for user in blogData.users:
    if user.id == id:
      return some(user)
  return none(User)

proc findPost(id: int): Option[Post] =
  for post in blogData.posts:
    if post.id == id:
      return some(post)
  return none(Post)

proc updateUser(user: User) =
  for i, u in blogData.users:
    if u.id == user.id:
      blogData.users[i] = user
      break

proc updatePost(post: Post) =
  for i, p in blogData.posts:
    if p.id == post.id:
      blogData.posts[i] = post
      break

type
  JsonPatchError = object of CatchableError

proc applyPatch(tree: var JsonTree, patch: JsonTree) =
  for operation in patch.items(JsonPtr"", JsonTree):
    let
      op = fromJson(operation, JsonPtr"/op", string)
      path = fromJson(operation, JsonPtr"/path", string).JsonPtr
    case op
    of "add":
      let value = fromJson(operation, JsonPtr"/value", JsonTree)
      tree.add(path, value)
    of "remove":
      tree.remove(path)
    of "replace":
      let value = fromJson(operation, JsonPtr"/value", JsonTree)
      tree.replace(path, value)
    of "move":
      let fromPath = fromJson(operation, JsonPtr"/from", string).JsonPtr
      tree.move(fromPath, path)
    of "copy":
      let fromPath = fromJson(operation, JsonPtr"/from", string).JsonPtr
      tree.copy(fromPath, path)
    of "test":
      let expected = fromJson(operation, JsonPtr"/value", JsonTree)
      if not tree.test(path, expected):
        raise newException(JsonPatchError, "Test operation failed")
    else:
      raise newException(JsonPatchError, "Invalid operation: " & op)

proc applyPatchToUser(patch: JsonTree, user: User): User =
  var jsonUser = user.toJson()
  applyPatch(jsonUser, patch)
  result = jsonUser.fromJson(JsonPtr"", User)

proc applyPatchToPost(patch: JsonTree, post: Post): Post =
  var jsonPost = post.toJson()
  applyPatch(jsonPost, patch)
  result = jsonPost.fromJson(JsonPtr"", Post)

proc updateUserEndpoint(id: int, patch: JsonTree): string =
  try:
    let user = findUser(id)
    if user.isNone():
      return "User not found"
    let patched = applyPatchToUser(patch, user.get())
    updateUser(patched)
    return "User updated successfully"
  except JsonPatchError:
    return "Internal Server Error"

proc updatePostEndpoint(id: int, patch: JsonTree): string =
  try:
    let post = findPost(id)
    if post.isNone():
      return "Post not found"
    let patched = applyPatchToPost(patch, post.get())
    updatePost(patched)
    "Post updated successfully"
  except JsonPatchError:
    "Internal Server Error"

proc main =
  var totalTime: float64 = 0
  for i in 1..iterations:
    let
      userId = rand(1..100)
      postId = rand(1..200)
    let startTime = cpuTime()
    let userPatch = %*[
      {"op": "test", "path": "/name", "value": "User " & $userId},
      {"op": "replace", "path": "/email", "value": "updated" & $userId & "@example.com"}
    ]
    discard updateUserEndpoint(userId, userPatch)
    let postPatch = %*[
      {"op": "test", "path": "/title", "value": "Post " & $postId},
      {"op": "add", "path": "/content", "value": " Updated content."}
    ]
    discard updatePostEndpoint(postId, postPatch)
    let endTime = cpuTime()
    totalTime += endTime - startTime
  let avgTime = totalTime / iterations.float64
  echo "Average time per patch application: ", avgTime.formatFloat(ffDecimal, 6), " seconds"

main()
