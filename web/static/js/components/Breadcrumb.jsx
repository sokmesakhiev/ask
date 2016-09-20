import React, { PropTypes } from 'react'
import { Link } from 'react-router'
import Breadcrumbs, { combineResolvers, key, resolver } from 'react-router-breadcrumbs'

// Override default react-router-breadcrumbs separator markup
const separator = (crumbElement, index, array) => ""

// By default, show the route name as the breadcrumb item
const defaultResolver = (key, text, routePath, route) => key

const hydrateLink = (inputLink, key, value) => {
	if (key) {
		return inputLink.replace(key, value)
	}
}

// The link param generated by react-router-breadcrumbs based on the react-router 
// config comes in the form "/projects/projectId/surveys/surveyId/[etc]".
// So we need to look for id placeholders in the route and replace them for the
// actual id's (which come in the "params" property).
const renderLink = (params) => (link, key, text, index, routes) => {
	let hydratedLink = hydrateLink(link, "projectId", params.projectId)
	hydratedLink = hydrateLink(hydratedLink, "surveyId", params.surveyId)
	hydratedLink = hydrateLink(hydratedLink, "questionnaireId", params.questionnaireId)

	return <Link className="breadcrumb" to={hydratedLink} key={key}>{text}</Link>
}

// The logo at the left of the breadcrumb
const logo =
	[<div key="0" className="logo">
    <img src='/images/logo.png' width='28px'/>
  </div>]

// This function resolves how a level of the breadcrumb looks
// when it points to an entity (right now only project, surveys and questionnaires)
const entityResolver = (project, survey, questionnaire) => (keyValue, text) => {
	if (keyValue === ':projectId') {
		if (project) {
			return project.name
		} else {
			return "Loading project..."
		}
	}

	if (keyValue === ':surveyId') {
		if (survey) {
			if (survey.name === "Untitled") {
				return "Untitled Survey"
			} else {
				return survey.name
			}
		} else {
			return "Loading survey..."
		}
	}

	if (keyValue === ':questionnaireId') {
		if (questionnaire) {
			if (questionnaire.name) {
				return questionnaire.name
			} else {
				return "Untitled Questionnaire"
			}
		} else {
			return "Loading questionnaire..."
		}
	}
}


const Breadcrumb = ({ params, project, survey, questionnaire, routes }) => {
	const breadcrumbResolver = combineResolvers(entityResolver(project, survey, questionnaire), defaultResolver)

	return (
		<nav id="Breadcrumb">
      <div className="nav-wrapper">
        <div className="row">
            <Breadcrumbs 
              routes={routes}
              resolver={breadcrumbResolver}
              createSeparator={separator}
              prefixElements = {logo}
              createLink={renderLink(params)}/>
        </div>
      </div>
    </nav>
	)
}

export default Breadcrumb