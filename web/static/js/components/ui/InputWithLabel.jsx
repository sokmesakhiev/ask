import React, { PropTypes, Component } from 'react'
import uuid from 'node-uuid'
import classNames from 'classnames/bind'

export class InputWithLabel extends Component {
  static propTypes = {
    children: PropTypes.node,
    id: PropTypes.any,
    value: PropTypes.oneOfType([
      PropTypes.string,
      PropTypes.number ]),
    label: PropTypes.node,
    className: PropTypes.string,
    errors: PropTypes.array,
    readOnly: PropTypes.bool
  }

  render() {
    const { children, className, value, label, errors, readOnly } = this.props
    const id = this.props.id || uuid.v4()

    var childrenWithProps = React.Children.map(children, function(child) {
      if (child) {
        if (readOnly) {
          return React.cloneElement(child, { id: id, value: value, disabled: readOnly })
        }
        return React.cloneElement(child, { id: id, value: value })
      } else {
        return null
      }
    })

    let errorMessage = null

    if (errors && errors.length > 0) {
      errorMessage = errors.join(', ')
    }

    return (
      <div className={className}>
        {childrenWithProps}
        <label htmlFor={id} className={classNames({'active': (value != null && value !== '')})} data-error={errorMessage}>{label}</label>
      </div>
    )
  }
}
