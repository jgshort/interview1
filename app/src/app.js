const COMMON_TAGS =  {
  'railway.public-domain': process.env.RAILWAY_PUBLIC_DOMAIN,
  'railway.private-domain': process.env.RAILWAY_PRIVATE_DOMAIN,
  'railway.project-name': process.env.RAILWAY_PROJECT_NAME,
  'railway.environment-name': process.env.RAILWAY_ENVIRONMENT_NAME,
  'railway.service-name': process.env.RAILWAY_SERVICE_NAME,
  'railway.project-id': process.env.RAILWAY_PROJECT_ID,
  'railway.environment-id': process.env.RAILWAY_ENVIRONMENT_ID,
  'railway.service-id': process.env.RAILWAY_SERVICE_ID
}

const tracer = require('dd-trace')
  .init({
    runtimeMetrics: true,
    logInjection: true,
    env: 'dev',
    service: 'sample',
    tags: COMMON_TAGS
  })

const { registerInstrumentations } = require('@opentelemetry/instrumentation')
const { HttpInstrumentation } = require('@opentelemetry/instrumentation-http');
const { ExpressInstrumentation } = require('@opentelemetry/instrumentation-express');
const otapi = require('@opentelemetry/api');
const StatsD = require('hot-shots');
const { createLogger, format, transports } = require('winston');
require('winston-syslog').Syslog;

const { TracerProvider } = tracer
const tracerProvider = new TracerProvider()
tracerProvider.register()

registerInstrumentations({
  tracerProvider,
  instrumentations: [
    new HttpInstrumentation(),
    new ExpressInstrumentation(),
  ],
})

const express = require('express')
const app = express()
const port = process.env.PORT || 3000
const server = require('http').createServer(app)

const statsdClient = new StatsD({
  host: process.env.DD_TRACE_AGENT_HOSTNAME,
  port: process.env.DD_AGENT_STATSD_PORT,
  protocol: 'udp',
  cacheDns: true,
  udpSocketOptions: {
    type: 'udp6',
    reuseAddr: true,
    ipv6Only: true,
  },
});

const logger = createLogger({
  level: 'info',
  exitOnError: false,
  format: format.json(),
  transports: [
    new transports.Syslog({
      host: process.env.DD_TRACE_AGENT_HOSTNAME,
      port: process.env.DD_AGENT_SYSLOG_PORT,
      protocol: 'udp6',
      format: format.json(),
      app_name: 'sample-api',
    }),
  ],
});

const spanTracer = otapi.trace.getTracer(COMMON_TAGS['railway.project-name']);

/* Tracks connections and terminates the server if requested */
const setConnectionKill = (server) => {
  const connections = []
  server.on('connection', (c) => {
    const key = `${c.remoteAddress}:${c.remotePort}`
    connections[key] = c
    c.on('close', () => delete c[key])
  })
  server.destroy = (cb) => {
    server.close(cb)
    for(const k in connections) {
      connections[k].destroy()
    }
  }
}

const SERVER_KIND = 1
const telemetry = (req, fn) => {
  tracer.dogstatsd.increment(`${req.originalUrl}.hits`, 1, COMMON_TAGS);
  const currentSpan = otapi.trace.getSpan(otapi.context.active())
  const span = spanTracer.startSpan(req.originalUrl, {
    kind: SERVER_KIND,
    attributes: COMMON_TAGS,
  })
  try {
    fn()
  } catch(err) {
    logger.error(err)
    throw err
  } finally {
    span.end()
  }
}

/* Utilized by the load balancer and Railway services to determine health */
app.get('/health', (req, res) => {
  telemetry(req, () => {
    res.sendStatus(200)
  })
})

/* Utilized by the Chaos Monkey to terminate the server. */
app.get('/boom', (req, res) => {
  telemetry(req, () => {
    server.destroy(() => {
      console.log('I slipped on a banana and now I\'m dead :(')
    })
  })
})

setConnectionKill(server)
server.listen(port, () => {
  console.log(`Listening on port ${port}`)
})

