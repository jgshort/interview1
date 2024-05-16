const RAILWAY_TOKEN = process.env.TOKEN_OF_CHAOS
const RAILWAY_PROJECT_ID = process.env.RAILWAY_PROJECT_ID

const protocol = 'https'

const apiFetch = async (url) => await fetch(url, {
  method: 'GET'
})

const railwayFetch = async (query, variables) => await fetch('https://backboard.railway.app/graphql/v2', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${RAILWAY_TOKEN}`
  },
  body: JSON.stringify({ query, variables })
})

const getEnvironment = async () => {
  const query = `query me {
    me { projects { edges {
      node { environments { edges { node {
        id name
      } } } }
    } } }
  }`
  try {
    const response = await railwayFetch(query)
    const json = await response.json()
    const project = json.data.me.projects.edges[0]
    const environments = project.node.environments.edges
    const environment = environments.filter(environment => environment.node.name === 'dev')[0]
    return environment.node.id
  } catch (err) {
    console.error(err)
    throw err
  }
}

const serviceDeploymentStatus = async (environmentId, serviceId) => {
  const query = `query ($environmentId: String!, $serviceId: String!) {
      serviceInstance(environmentId: $environmentId, serviceId: $serviceId) {
        id, latestDeployment { id, status }
      }
  }`
  const variables = { environmentId, serviceId }
  try {
    const response = await railwayFetch(query, variables)
    const json = await response.json()
    return json.data.serviceInstance.latestDeployment
  } catch(err) {
    throw err
  }
}

const serviceDomains = async (environmentId, serviceId) => {
  const query = `query ($environmentId: String!, $projectId: String!, $serviceId: String!) {
    domains(environmentId: $environmentId, projectId: $projectId, serviceId: $serviceId) {
      serviceDomains { domain }
    }
  }`
  const variables = { environmentId, projectId: RAILWAY_PROJECT_ID, serviceId }
  try {
    const response = await railwayFetch(query, variables)
    const json = await response.json()
    return json.data.domains.serviceDomains
  } catch(err) {
    console.error(err)
    throw err
  }
}

const getServices = async (environmentId) => {
  const query = `query me {
    me { projects {
      edges { node { services {
        edges { node {
          id name
        } }
      } } }
    } }
  }`
  try {
    const response = await railwayFetch(query)
    const json = await response.json()
    const projects = json.data.me.projects.edges[0]
    const services = projects.node.services.edges
    const matches = services.filter(service => service.node.name.indexOf("Sample API") !== -1)
    const statuses = []
    for(const match of matches) {
      const serviceId = match.node.id
      const latestDeployment = await serviceDeploymentStatus(environmentId, serviceId);
      statuses.push({ serviceId, latestDeployment })
    }
    return statuses
  } catch(err) {
    console.error(err)
    throw err;
  }
}

const restartService = async (deploymentId) => {
  const query = `mutation deploymentRestart($id: String!) { deploymentRestart(id: $id) }`
  const variables = { id: deploymentId }
  try {
    const response = await railwayFetch(query, variables)
    const json = await response.json()
    console.log(JSON.stringify(json))
  } catch(err) {
    console.error(err)
    throw err
  }
}

const countHealthyServices = async (environmentId, services) => {
  let count = 0
  let total = 0
  for(const service of services) {
    const domains = await serviceDomains(environmentId, service.serviceId)
    for(const domain of domains) {
      const healthUrl = `${protocol}://${domain.domain}/health`
      try {
        const response = await apiFetch(healthUrl)
        if(response.ok) {
          console.log(`${healthUrl} is healthy.`)
          count++
        } else {
          console.log(`${healthUrl} is unhealthy.`)
        }
        total++
      } catch(err) {
        console.error(err)
      }
    }
  }
  return { total, count }
}

const throwBanana = async (environmentId, service) => {
  const maxRetries = 10
  const domains = await serviceDomains(environmentId, service.serviceId)
  for(const domain of domains) {
    for(let i = 0; i < maxRetries; i++) {
      const delay = ms => new Promise(resolve => setTimeout(resolve, ms))
      const boomUrl = `${protocol}://${domain.domain}/boom`
      try {
        const response = await apiFetch(boomUrl)
      } catch(err) {
        if(err.cause.code === 'UND_ERR_SOCKET') {
          console.log(`🍌 I Mario Kart'd ${domain.domain}!`)
        } else {
          console.log(`Connection refused; trying again in a second...`)
          console.error(err)
        }
      }
      await delay(5000)
    }
  }
}

const undoChaos = async (environmentId, services) => {
  const restart = async (service) => {
    console.log(`Restarting ${service.latestDeployment.id}`)
    await restartService(service.latestDeployment.id)
  }
  for(const service of services) {
    const domains = await serviceDomains(environmentId, service.serviceId)
    for(const domain of domains) {
      const delay = ms => new Promise(resolve => setTimeout(resolve, ms))
      const healthUrl = `${protocol}://${domain.domain}/health`
      try {
        const response = await apiFetch(healthUrl)
        if(!response.ok) {
          await restart(service)
        }
      } catch(err) {
        await restart(service)
        console.error(err)
      }
      await delay(5000)
    }
  }
}

const createChaos = async () => {
  const environmentId = await getEnvironment()
  const services = await getServices(environmentId)
  const { count, total } = await countHealthyServices(environmentId, services)
  if(count < total) {
    console.log('✅ Too many monkeys, undoing chaos.')
    await undoChaos(environmentId, services)
  } else {
    console.log('🐒 Time to... monkey around!')
    const random = Math.floor(Math.random() * services.length);
    const serviceToBreak = services[random]
    console.log(`🍌 Throwing a banana at ${serviceToBreak.serviceId}...`);
    await throwBanana(environmentId, serviceToBreak)
  }
}

(async () => {
  console.log('☠️ I am an agent of chaos.');
  await createChaos()
})()

