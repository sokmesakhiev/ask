import * as api from '../api'

export const NEW = 'QUESTIONNAIRE_NEW'
export const FETCH = 'QUESTIONNAIRE_FETCH'
export const RECEIVE = 'QUESTIONNAIRE_RECEIVE'
export const CHANGE_NAME = 'QUESTIONNAIRE_CHANGE_NAME'
export const TOGGLE_MODE = 'QUESTIONNAIRE_TOGGLE_MODE'
export const ADD_STEP = 'QUESTIONNAIRE_ADD_STEP'
export const DELETE_STEP = 'QUESTIONNAIRE_DELETE_STEP'
export const CHANGE_STEP_TITLE = 'QUESTIONNAIRE_CHANGE_STEP_TITLE'
export const CHANGE_STEP_TYPE = 'QUESTIONNAIRE_CHANGE_STEP_TYPE'
export const CHANGE_STEP_PROMPT_SMS = 'QUESTIONNAIRE_CHANGE_STEP_PROMPT_SMS'
export const CHANGE_STEP_PROMPT_IVR = 'QUESTIONNAIRE_CHANGE_STEP_PROMPT_IVR'
export const CHANGE_STEP_AUDIO_ID_IVR = 'QUESTIONNAIRE_CHANGE_STEP_AUDIO_ID_IVR'
export const CHANGE_STEP_STORE = 'QUESTIONNAIRE_CHANGE_STEP_STORE'
export const ADD_CHOICE = 'QUESTIONNAIRE_ADD_CHOICE'
export const DELETE_CHOICE = 'QUESTIONNAIRE_DELETE_CHOICE'
export const CHANGE_CHOICE = 'QUESTIONNAIRE_CHANGE_CHOICE'

export const fetchQuestionnaire = (projectId, questionnaireId) => (dispatch, getState) => {
  dispatch(fetch(projectId, questionnaireId))
  return api.fetchQuestionnaire(projectId, questionnaireId)
    .then(response => {
      dispatch(receive(response.entities.questionnaires[response.result]))
    })
    .then(() => {
      return getState().questionnaire.data
    })
}

export const fetch = (projectId, questionnaireId) => ({
  type: FETCH,
  projectId,
  questionnaireId
})

export const fetchQuestionnaireIfNeeded = (projectId, questionnaireId) => {
  return (dispatch, getState) => {
    if (shouldFetch(getState().questionnaire, projectId, questionnaireId)) {
      return dispatch(fetchQuestionnaire(projectId, questionnaireId))
    } else {
      return Promise.resolve(getState().questionnaire.data)
    }
  }
}

export const receive = (questionnaire) => ({
  type: RECEIVE,
  questionnaire
})

export const shouldFetch = (state, projectId, questionnaireId) => {
  return !state.fetching || !(state.filter && (state.filter.projectId == projectId && state.filter.questionnaireId == questionnaireId))
}

export const addChoice = (stepId) => ({
  type: ADD_CHOICE,
  stepId
})

export const changeChoice = (stepId, index, response, smsValues, ivrValues, skipLogic, autoComplete = false) => ({
  type: CHANGE_CHOICE,
  choiceChange: { index, response, smsValues, ivrValues, skipLogic, autoComplete },
  stepId
})

export const deleteChoice = (stepId, index) => ({
  type: DELETE_CHOICE,
  stepId,
  index
})

export const deleteStep = (stepId) => ({
  type: DELETE_STEP,
  stepId
})

export const changeStepStore = (stepId, newStore) => ({
  type: CHANGE_STEP_STORE,
  stepId,
  newStore
})

export const changeStepPromptSms = (stepId, newPrompt) => ({
  type: CHANGE_STEP_PROMPT_SMS,
  stepId,
  newPrompt
})

export const changeStepPromptIvr = (stepId, newPrompt) => ({
  type: CHANGE_STEP_PROMPT_IVR,
  stepId,
  newPrompt
})

export const changeStepAudioIdIvr = (stepId, newId) => ({
  type: CHANGE_STEP_AUDIO_ID_IVR,
  stepId,
  newId
})


export const changeStepTitle = (stepId, newTitle) => ({
  type: CHANGE_STEP_TITLE,
  stepId,
  newTitle
})

export const changeStepType = (stepId, stepType) => ({
  type: CHANGE_STEP_TYPE,
  stepId,
  stepType
})

export const addStep = () => ({
  type: ADD_STEP
})

export const newQuestionnaire = (projectId) => ({
  type: NEW,
  projectId
})

export const changeName = (newName) => ({
  type: CHANGE_NAME,
  newName
})

export const toggleMode = (mode) => ({
  type: TOGGLE_MODE,
  mode
})

export const updateQuestionnaire = (questionnaire) => dispatch => {
  return dispatch(receive(questionnaire))
}

export const save = () => {
  return (dispatch, getState) => {
    const questionnaire = getState().questionnaire.data
    if (questionnaire.id) {
      api.updateQuestionnaire(questionnaire.projectId, questionnaire)
    } else {
      api.createQuestionnaire(questionnaire.projectId, questionnaire)
    }
  }
}
