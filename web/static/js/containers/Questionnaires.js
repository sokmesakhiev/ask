import React, { Component, PropTypes } from 'react'
import { connect } from 'react-redux'
import { Link } from 'react-router'
import * as actions from '../actions/questionnaires'
import { ProjectTabs } from '../components'
import { Tooltip } from '../components/Tooltip'

class Questionnaires extends Component {
  componentDidMount() {
    const { dispatch, projectId } = this.props
    dispatch(actions.fetchQuestionnaires(projectId))
  }

  render() {
    const { questionnaires, projectId } = this.props
    return (
      <div>
        <Tooltip text="Add questionnaire">
          <Link className="btn-floating btn-large waves-effect waves-light green right mtop" to={`/projects/${projectId}/questionnaires/new`}>
            <i className="material-icons">add</i>
          </Link>
        </Tooltip>
        <table className="ncdtable">
          <thead>
            <tr>
              <th>Name</th>
              <th>Modes</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            { Object.keys(questionnaires).map((questionnaireId) =>
              <tr key={questionnaireId}>
                <td>
                  { questionnaires[questionnaireId].name }
                </td>
                <td>
                  { (questionnaires[questionnaireId].modes || []).join(", ") }
                </td>
                <td>
                  <Link to={`/projects/${projectId}/questionnaires/${questionnaireId}/edit`}>Edit</Link>
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    )
  }
}

const mapStateToProps = (state, ownProps) => ({
  projectId: ownProps.params.projectId,
  questionnaires: state.questionnaires
})

export default connect(mapStateToProps)(Questionnaires)