const app = require("express")()
const server = require("http").createServer(app)
const port = process.env.PORT || "8080"
const message = process.env.MESSAGE || 'Hello World'

app.get('/', (req, res) => res.send(message))
server.listen(port, function () {
    console.log(`App listening on ${port}`)
});

