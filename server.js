const http = require("http")
const fs = require("fs")
const port = 1414
const key = "Ваш 'токен'"
const logsPath = "logs/"
const usersPath = "users/"
const users = new Object()

function zero(value) {
    return value <= 9 ? "0" : ""
}

function getTime(type) {
    let full = new Date()

    let day = full.getDate()
    let month = full.getMonth()
    let year = full.getFullYear()

    let hour = full.getHours()
    let minute = full.getMinutes()
    let second = full.getSeconds()

    if (type == "full") {
        return zero(day) + day + "." + month + "." + year + " " + zero(hour) + hour + ":" + zero(minute) + minute + ":" + zero(second) + second
    } else if (type == "time") {
        return "[" + zero(hour) + hour + ":" + zero(minute) + minute + ":" + zero(second) + second + "] "
    } else if (type == "log") {
        return zero(day) + day + "." + month + "." + year
    }
}

function checkPath(path) {
    if (!fs.existsSync(path)) {
        fs.mkdirSync(path)
    }
}

function log(data, custom) {
    let time = getTime("time")
    console.log(time + data)
    checkPath(logsPath)

    fs.appendFile(logsPath + (custom ? custom : getTime("log")) + ".log", (custom ? "[" + getTime("full") + "]" : time) + data + "\n", function(err) {
        if (err) {
            console.log(err)
        }
    })
}

function readUser(user, server) {
    let exists = fs.existsSync(usersPath + user + ".txt")

    if (exists) {
        let data = fs.readFileSync(usersPath + user + ".txt", "utf8")
        if (data != "") {
            users[user] = JSON.parse(data)
        }
    } else if (!exists && users[user] && server) {
        delete users[user]
        reg(user, server)
    }
}

function readUsers(ignoreUser) {
    checkPath(usersPath)
    let files = fs.readdirSync(usersPath)

    if (files.length >= 0) {
        for (let i = 0; i < files.length && files[i] != ignoreUser; i++) {
            let checkUser = files[i].match(/(([^.txt][a-zA-Zа-яА-Я0-9_]+))/u)

            if (checkUser[1]) {
                readUser(checkUser[1])
            } else {
                log("INVALID USER " + files[i] + " ON USERS PATH!")
            }
        }
    }
}

function updateUser(user) {
    checkPath(usersPath)

    fs.writeFile(usersPath + user + ".txt", JSON.stringify(users[user]), function(err) {
        if (err) {
            log(err)
        }
    })
}

function reg(user, server) {
    log("Registration user " + user)
    let time = getTime("full")

    users[user] = new Object()
    users[user].balance = new Object()
    users[user].balance[server] = 0
    users[user].transactions = 0
    users[user].lastLogin = time
    users[user].regTime = time
    users[user].feedback = "none"
    users[user].foodTime = 0
    users[user].banned = "false"

    updateUser(user)
}

function login(user, server) {
    if (users[user]) {
        if (!users[user].balance[server]) {
            console.log(server)
            users[user].balance[server] = 0
        }
        log("User login " + user)
        users[user].lastLogin = getTime("full")
        updateUser(user)
    } else {
        reg(user, server)
        login(user, server)
    }
}

function responseHandler(url, response) {
    log("URL " + url)

    let checkKey = url.match(/\?key=([a-zA-Z0-9]+)/u)

    if (checkKey && checkKey[1] == key) {
        let server = url.match(/&server=([a-zA-Z]+)/u)

        if (server && server[1]) {
            let method = url.match(/&method=([a-zA-Z]+)/u)

            if (method && method[1]) {
                if (method[1] == "login" || method[1] == "update") {
                    let user = url.match(/&user=([a-zA-Zа-яА-Я0-9_]+)/u)
                    let operationLog = url.match(/&log=([^&]*)/u)

                    if (operationLog && operationLog[1]) {
                        log("(" + user[1] + ")" + operationLog[1], "operations")
                    }

                    if (user && user[1]) {
                        readUser(user[1], server[1])
                        readUsers(user[1])

                        if (method[1] == "login") {
                            let feedbacks = "feedbacks="
                            login(user[1], server[1])
                            response.write("balance=" + users[user[1]].balance[server[1]] + ";transactions=" + users[user[1]].transactions + ";lastLogin=" + users[user[1]].lastLogin + ";regTime=" + users[user[1]].regTime + ";feedback=" + users[user[1]].feedback + ";foodTime=" + users[user[1]].foodTime + ";banned=" + users[user[1]].banned + ";")

                            for (userFeedback in users) {
                                if (users[userFeedback].feedback != "none") {
                                    feedbacks = feedbacks + "[user=" + userFeedback + "&feedback=" + users[userFeedback].feedback + "];"
                                }
                            }

                            if (feedbacks != "feedbacks=") {
                                response.write(feedbacks)
                            }
                        } else if (method[1] == "update") {
                            log("Update user " + user[1])
                            let balance = url.match(/&balance=(\d+)/u)
                            let transactions = url.match(/&transactions=(\d+)/u)
                            let feedback = url.match(/&feedback=([^&]*)/u)
                            let foodTime = url.match(/&foodTime=(\d+)/u)

                            users[user[1]].balance[server[1]] = balance ? Number(balance[1]) : users[user[1]].balance[server[1]]
                            users[user[1]].transactions = transactions ? Number(transactions[1]) : users[user[1]].transactions
                            users[user[1]].feedback = feedback ? feedback[1] : users[user[1]].feedback
                            users[user[1]].foodTime = foodTime ? Number(foodTime[1]) : users[user[1]].foodTime

                            updateUser(user[1])
                            response.write("Update successful")
                        }

                        console.log(users[user[1]])
                    } else {
                        response.write("Invalid user")
                        log("Invalid user")
                    }
                } else {
                    response.write("Method " + method[1] + " not found")
                    log("Method " + method[1] + " not found")
                }
            } else {
                response.write("Invalid method")
                log("Invalid method")
            }
        } else {
            response.write("Invalid server")
            log("Invalid server")
        }
    } else {
        response.write("Invalid key")
        log("Invalid key")
    }
}

function requestHandler(request, response) {
    log("Request from IP " + request.connection.remoteAddress)
    response.writeHead(200, {
        "Content-Type": "text/html; charset=utf-8"
    })

    if (request.url != "/favicon.ico" && request.url != "/") {
        let url = decodeURIComponent(request.url)

        responseHandler(url, response)
        response.end()
    } else {
        response.end("RipMarket, bitch!")
    }
}

const server = http.createServer(requestHandler)

server.listen(port, (err) => {
    if (err) {
        log("Something bad happened " + err)
        process.exit()
    } else {
        log("RipMarket started on port " + port + "!")
        readUsers()
    }
})
