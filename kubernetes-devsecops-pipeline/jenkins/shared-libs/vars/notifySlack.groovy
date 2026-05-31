/**
 * Shared library step: send a Slack notification.
 * Usage: notifySlack(status: 'success', message: 'Deployed v1.2.3')
 */
def call(Map config) {
    def color = [success: 'good', failure: 'danger', warning: 'warning'].get(config.status, '#439FE0')
    slackSend(channel: config.get('channel', '#deployments'), color: color, message: config.message)
}
