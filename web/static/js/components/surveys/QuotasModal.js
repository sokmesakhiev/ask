import React, { Component, PropTypes } from 'react'
import { stepStoreValues } from '../../reducers/questionnaire'
import filter from 'lodash/filter'
import map from 'lodash/map'
import includes from 'lodash/includes'

export class QuotasModal extends Component {
  static propTypes = {
    showLink: PropTypes.bool,
    linkText: PropTypes.string,
    header: PropTypes.string.isRequired,
    survey: PropTypes.object.isRequired,
    questionnaire: PropTypes.object.isRequired,
    onConfirm: PropTypes.func.isRequired,
    modalId: PropTypes.string.isRequired,
    style: PropTypes.object
  }

  constructor(props) {
    super(props)
    this.state = {
      buckets: {},
      steps: {}
    }
    this.onSubmit = this.onSubmit.bind(this)
  }

  componentDidMount() {
    $(document).ready(function() {
      $('.modal').modal()
    })
  }

  onSubmit(e) {
    const selectedVars = map(filter(Object.keys(this.state.buckets), value =>
      this.state.buckets[value].checked
    ), (quotaVar) => ({
      var: quotaVar,
      steps: (this.state.steps[quotaVar] || '').value
    }))
    this.props.onConfirm(selectedVars)
  }

  render() {
    const { showLink, linkText, header, survey, questionnaire, modalId, style } = this.props

    let modalLink = null
    if (showLink) {
      modalLink = (<a className='modal-trigger' href={`#${modalId}`}>{linkText}</a>)
    }
    const storeValues = stepStoreValues(questionnaire)

    return (
      <div>
        {modalLink}
        <div id={modalId} className='modal' style={style}>
          <div className='modal-content'>
            <h4>{header}</h4>
            {Object.keys(storeValues).map((storeValue) =>
              <div className='row' key={storeValue} >
                <div className={`col ${storeValues[storeValue].type == 'numeric' ? 's4' : 's10'}`}>
                  <i className='material-icons v-middle left'>list</i>
                  <span className='mode-label'>{storeValue}</span>
                </div>
                { storeValues[storeValue].type == 'numeric'
                  ? <div className='col s6'>
                    <input
                      type='text'
                      ref={node => { this.state.steps[storeValue] = node }}
                      />
                  </div>
                  : ''
                }
                <div className='col s1'>
                  <input type='checkbox' className='filled-in' id={storeValue} defaultChecked={includes(survey.quotas.vars, storeValue)} ref={node => { this.state.buckets[storeValue] = node }} />
                  <label htmlFor={storeValue} />
                </div>
              </div>
            )}
          </div>
          <div className='modal-footer'>
            <a href='#!' className=' modal-action modal-close waves-effect waves-green btn-flat' onClick={this.onSubmit}>DONE</a>
            <a href='#!' className=' modal-action modal-close waves-effect waves-green btn-flat'>Cancel</a>
          </div>
        </div>
      </div>
    )
  }
}
