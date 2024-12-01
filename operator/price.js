const http = require('http');

const getPrice = (symbol) => {
    console.log('Getting price for', symbol);
    const req = http.request({
        hostname: 'data-api.binance.vision',
        path: '/api/v3/ticker/price?symbol=' + symbol,
        method: 'GET'
    }, (res) => {
        let data = '';

        res.on('data', (chunk) => {
            data += chunk;
        });

        res.on('end', () => {
            try {
                const parsedData = JSON.parse(data);
                console.log('Price received:', parsedData.price);
                resolve(parsedData.price);
            } catch (e) {
                reject(`Error parsing JSON: ${e.message}`);
            }
        });
    });

    req.on('error', (e) => {
        console.error(`problem with request: ${e.message}`);
    });

    req.end();
}

module.exports = { getPrice };