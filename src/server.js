const http = require('http');
const express = require('express')
const cors = require('cors')
const app = express()

const port = 3000;

const options = {
    treatRequest: function(event, repo, ref, data) {
        switch(event) {
            case 'pull_request':
                processEvent(repo, ref, data);
                break;
        }
    }
}

function processEvent(repo, ref, data) {
    const action = data.action

    // If PR is merged
    if (action === 'closed' && data.pull_request.merged === true) {

        // Get the relevant address for the PR, send the funds from it to the PR creator

    }

    if (action === 'opened') {

        // Get new instance of Cheer from deployed CheerFactory

    }

    console.log(data);
}

app.use('/webhook', require('express-github-hook')(options));

app.get('/cheer', () => {
    console.log('cheer');
})

app.get('/prbounty', cors(), (req, res, next) => {
    console.log(req.query)
    res.json({amount: 0.3003})
})

app.listen(port, () => {
    console.log('App is now listening on port 3000');
})
