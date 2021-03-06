import React, { Component } from 'react'
import { UntitledIfEmpty } from '.'
import classNames from 'classnames/bind'

export class EditableTitleLabel extends Component {
  static propTypes = {
    onSubmit: React.PropTypes.func.isRequired,
    title: React.PropTypes.string,
    emptyText: React.PropTypes.string,
    entityName: React.PropTypes.string,
    editing: React.PropTypes.bool,
    readOnly: React.PropTypes.bool,
    more: React.PropTypes.node
  }

  constructor(props) {
    super(props)
    this.state = {
      editing: false
    }
    this.inputRef = null
  }

  handleClick() {
    if (!this.state.editing && !this.props.readOnly) {
      this.setState({editing: !this.state.editing})
    }
  }

  endEdit() {
    this.setState({editing: false})
  }

  endAndSubmit() {
    const { onSubmit } = this.props
    this.endEdit()
    onSubmit(this.inputRef.value)
  }

  onKeyDown(event) {
    if (event.key == 'Enter') {
      this.endAndSubmit()
    } else if (event.key == 'Escape') {
      this.endEdit()
    }
  }

  render() {
    const { title, emptyText, entityName, more } = this.props

    let icon = null
    if ((!title || title.trim() == '') && !this.props.readOnly) {
      icon = <i className='material-icons'>mode_edit</i>
    }

    if (!this.state.editing) {
      return (
        <div className='title'>
          <a className={classNames({'page-title': true, 'truncate': (title && title.trim() != '')})} onClick={e => this.handleClick(e)}>
            <UntitledIfEmpty text={title} emptyText={emptyText} entityName={entityName} />
            {icon}
          </a>
          {more}
        </div>
      )
    } else {
      return (
        <input
          type='text'
          ref={node => { this.inputRef = node }}
          autoFocus
          maxLength='255'
          defaultValue={title}
          onKeyDown={e => this.onKeyDown(e)}
          onBlur={e => this.endAndSubmit(e)}
          />
      )
    }
  }
}
