import React, { Component, PropTypes } from 'react'
import { connect } from 'react-redux'
import { UntitledIfEmpty } from '../ui'

class QuestionnaireClosedStep extends Component {
  render() {
    const { step, onClick } = this.props

    return (
      <a href='#!' className='truncate' onClick={event => {
        event.preventDefault()
        onClick(step.id)
      }}>
        {step.type == 'multiple-choice' ? <i className='material-icons left'>list</i> : step.type == 'numeric' ? <i className='material-icons sharp left'>dialpad</i> : <i className='material-icons left'>language</i>}
        <UntitledIfEmpty text={step.title} emptyText='Untitled question' />
        <i className='material-icons right grey-text'>expand_more</i>
      </a>
    )
  }
}

QuestionnaireClosedStep.propTypes = {
  step: PropTypes.object.isRequired,
  onClick: PropTypes.func.isRequired
}

export default connect()(QuestionnaireClosedStep)
