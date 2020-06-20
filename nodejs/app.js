const app = require("express")();
const server = require("http").createServer(app);
const port = process.env.PORT || "8080";

app.get('/', (req, res) => res.send('Hello World'));
server.listen(port, function () {
    console.log(`App listening on ${port}`);
});

